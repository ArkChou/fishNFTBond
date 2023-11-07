// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@sushiswap/core/contracts/uniswapv2/interfaces/IUniswapV2Pair.sol";
import "@sushiswap/core/contracts/uniswapv2/interfaces/IUniswapV2Factory.sol";
import "@sushiswap/core/contracts/uniswapv2/interfaces/IUniswapV2Router02.sol";
import "./libraries/IOracle.sol";

library Math {
    function min(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = x < y ? x : y;
    }

    // babylonian method (https://en.wikipedia.org/wiki/Methods_of_computing_square_roots#Babylonian_method)
    function sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }
}



interface IFISH {
    function mint(address account_, uint256 amount_) external returns (bool);
}

interface IFISHNFT {
    function totalSupply() external view returns (uint256);

    function mintFromExecutor(
        address _to,
        uint256 _seed,
        uint256 _remainingReward
    ) external returns (bool);
}

contract usdcBuyNftLogic is Initializable,OwnableUpgradeable{
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using SafeMath for uint256;

    uint256 public exchangeRate;//FISH的价格
    IOracle public oracle;  //oracle的地址
    bytes public oracleData;
    address public sFISH;  //sToken的地址
    address public multiSignature;  //多签地址
    address public multiSignatureToSToken;
    address public dev; //开发者地址
    address public op;  //运营团队的地址
    IUniswapV2Factory public Factory;
    IUniswapV2Router02 public Router;
    IERC20Upgradeable public USDC;  
    uint256 public maxSellAmt;  //最大销售数量
    IFISH public FISH;
    IFISHNFT public FISHNFT;   
    uint256  public ROI;//百分比收益比
    uint256 public PRECISION; //百分比分母
    uint256 public direction;
    uint256 public stepSize; //步长:方向
    uint256 public TargetROI; //目标的ROI
    uint256 public price;  //买NFT的价格
    mapping(address => uint256) public whitelistLevel;
    mapping(uint256 => uint256) public whitelistDiscount;
    uint256 public toLiquidityPec;  //给百分之多少添加到流动性
    bool public addLiquidityOpen;// 添加流动性开关
    uint256 public toDevPec;  //给百分之多少给开发者
    uint256 public toOpPec;  //给百分之多少给运营团队
    bool public stateOpen;//状态是否开启

    function initialize(
        IFISH _FISH,
        IFISHNFT _FISHNFT,
        IUniswapV2Factory _Factory,
        IUniswapV2Router02 _Router,
        address _multiSignature,
        address _multiSignatureToSToken,
        address _dev,
        address _op,
        address _sFISH,
        IOracle _oracle,
        IERC20Upgradeable _USDC
    ) external initializer {
        __Ownable_init();
        USDC = _USDC;
        oracle = _oracle;
        dev = _dev;
        op = _op;
        multiSignature = _multiSignature;
        multiSignatureToSToken = _multiSignatureToSToken;
        Router = _Router;
        Factory = _Factory;
        FISH = _FISH;
        FISHNFT = _FISHNFT;
        sFISH = _sFISH;
        PRECISION = 10000;
        ROI = 10000;
        direction = 0;
        stepSize = 100;
        TargetROI = 1000;
        price = 100 * 1e18;
        whitelistDiscount[0] = 10000;
        whitelistDiscount[1] = 9000;
        whitelistDiscount[2] = 8000;
        maxSellAmt = 1000;
        toLiquidityPec = 5000;
        toDevPec = 1500;
        toOpPec = 1500;
        addLiquidityOpen = false;
        stateOpen = false;
    }

    function sortTokens(address tokenA, address tokenB)
        internal
        pure
        returns (address token0, address token1)
    {
        require(tokenA != tokenB, "UniswapV2Library: IDENTICAL_ADDRESSES");
        (token0, token1) = tokenA < tokenB
            ? (tokenA, tokenB)
            : (tokenB, tokenA);
        require(token0 != address(0), "UniswapV2Library: ZERO_ADDRESS");
    }

    function updateRoi() internal returns (bool) {
        if (direction == 1) {
            if (ROI < TargetROI) {
                ROI = ROI.add(stepSize);
            }
        } else if (direction == 2) {
            if (ROI > TargetROI) {
                ROI = ROI.sub(stepSize);
            }
        } else {}
        return true;
    }

    
    function setOracle(IOracle _newOracle, bytes memory _newOracleData)
        public
        onlyOwner
        returns (bool)
    {
        oracle = _newOracle;
        oracleData = _newOracleData;
        return true;
    }

    function setToLiquidityPec(uint256 _toLiquidityPec)
        public
        onlyOwner
        returns (bool)
    {
        toLiquidityPec = _toLiquidityPec;
        return true;
    }

    function setToDevPec(uint256 _toDevPec) public onlyOwner returns (bool) {
        toDevPec = _toDevPec;
        return true;
    }

    function setAddLiquidityOpen(bool _bool) public onlyOwner returns (bool) {
        addLiquidityOpen = _bool;
        return true;
    }

    function setToOpPec(uint256 _toOpPec) public onlyOwner returns (bool) {
        toOpPec = _toOpPec;
        return true;
    }

    function setDev(address _dev) public onlyOwner returns (bool) {
        dev = _dev;
        return true;
    }

    function setOp(address _op) public onlyOwner returns (bool) {
        op = _op;
        return true;
    }

    function setMultiSignature(address _multiSignature)
        public
        onlyOwner
        returns (bool)
    {
        multiSignature = _multiSignature;
        return true;
    }

    function setMultiSignatureToSToken(address _multiSignatureToSToken)
        public
        onlyOwner
        returns (bool)
    {
        multiSignatureToSToken = _multiSignatureToSToken;
        return true;
    }

    function setStateOpen(bool _bool) public onlyOwner returns (bool) {
        stateOpen = _bool;
        return true;
    }

    function setMaxSellAmt(uint256 _val) public onlyOwner returns (bool) {
        maxSellAmt = _val;
        return true;
    }

    function setROI(uint256 _val) public onlyOwner returns (bool) {
        ROI = _val;
        return true;
    }

    function setDirection(uint256 _val) public onlyOwner returns (bool) {
        direction = _val;
        return true;
    }

    function setStepSize(uint256 _val) public onlyOwner returns (bool) {
        stepSize = _val;
        return true;
    }

    function setTargetROI(uint256 _val) public onlyOwner returns (bool) {
        TargetROI = _val;
        return true;
    }

    function setPrice(uint256 _val) public onlyOwner returns (bool) {
        price = _val;
        return true;
    }

    function setWhitelistLevel(address _user, uint256 _lev)
        public
        onlyOwner
        returns (bool)
    {
        whitelistLevel[_user] = _lev;
        return true;
    }

    function setWhitelistDiscount(uint256 _val, uint256 _lev)
        public
        onlyOwner
        returns (bool)
    {
        whitelistDiscount[_val] = _lev;
        return true;
    }

    function updateExchangeRate() public returns (bool updated, uint256 rate) {
        (updated, rate) = oracle.get(oracleData);
        if (updated) {
            exchangeRate = rate;
        } else {
            // Return the old rate if fetching wasn't successful
            rate = exchangeRate;
        }
    }

    function peekSpot() public view returns (uint256) {
        return oracle.peekSpot("0x");
    }

    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) internal pure returns (uint256 amountOut) {
        uint256 amountInWithFee = amountIn.mul(997);     //要扣千分之三,
        uint256 numerator = amountInWithFee.mul(reserveOut);  
        uint256 denominator = reserveIn.mul(1000).add(amountInWithFee);
        amountOut = numerator / denominator;
    }

    function buyNFT(uint256 _amt) public  returns (bool) {
        uint256 amt = _amt;  //要购买NFT的数量
        require(tx.origin == _msgSender(),"Only EOA"); // 防止外部合约调用的一个方法
                                                       //表示这个function不能用合约去调用.只能用人或者个人钱包去调用
        uint256 amount = price  //购买NFT要花费usdc的数量
            .mul(amt)
            .mul(whitelistDiscount[whitelistLevel[msg.sender]])
            .div(PRECISION);
        IERC20Upgradeable(address(USDC)).safeTransferFrom(
            msg.sender,
            address(this),
            amount
        );

        uint256 amountUSDCToLiquidity = amount.mul(toLiquidityPec).div(PRECISION);  //要发送给LP的数量
        uint256 amountUSDCToDev = amount.mul(toDevPec).div(PRECISION);              //要发送给开发者的数量
        uint256 amountUSDCToOp = amount.mul(toOpPec).div(PRECISION);                //要发送给运营团队的数量
        uint256 amountUSDCToSFISH = amount                                          //剩下的就是发给FISH币的数量
            .sub(amountUSDCToLiquidity)
            .sub(amountUSDCToDev)
            .sub(amountUSDCToOp);   //SToken的奖励

         address pairAddress = Factory.getPair(address(USDC), address(FISH));        //用getPair方法获得LP的地址
         (address token0,) = sortTokens(address(USDC),address(FISH));    //token0只包含一个地址，即排序后的结果中较小的那个地址。在这段代码中，sortTokens函数返回的是一个元组，使用(address token0,)的方式将其中的第一个元素（即较小的地址）赋值给了token0变量。因此，token0中只存储了一个地址。

        if(addLiquidityOpen){
            IERC20Upgradeable(address(USDC)).safeApprove(address(Router), 0);
            IERC20Upgradeable(address(USDC)).safeApprove(
                address(Router),
                type(uint256).max
            );
            IERC20Upgradeable(address(FISH)).safeApprove(address(Router), 0);
            IERC20Upgradeable(address(FISH)).safeApprove(
                address(Router),
                type(uint256).max
            );

            calAndSwap(
                IUniswapV2Pair(pairAddress),
                address(FISH),
                address(USDC),
                amountUSDCToLiquidity
            );                                  //传给LP的有amountUSDCToLiquidity多的USDC,用其一半USDC去购买FISH?剩下的添加到流动性

            uint256 addLiquidityForUSDC = IERC20Upgradeable(address(USDC))
                .balanceOf(address(this))
                .sub(amountUSDCToDev)
                .sub(amountUSDCToOp)
                .sub(amountUSDCToSFISH);       //得到要添加于流动性的USDC代币数量
            Router.addLiquidity(
                address(USDC),
                address(FISH),
                addLiquidityForUSDC,
                IERC20Upgradeable(address(FISH)).balanceOf(address(this)),    //当前合约持有FISH币的数量
                0,
                0,
                multiSignature,
                block.timestamp + 1000
            );

        }else {
            USDC.safeTransfer(address(multiSignature), amountUSDCToLiquidity); //如果项目还没有发行,就先把要转入LP的钱转到多签地址,到时候再统一添加到流动性
        }

        USDC.safeTransfer(address(dev), amountUSDCToDev);   //钱转给开发者团队
        USDC.safeTransfer(address(op), amountUSDCToOp);     //钱转给运营团队

        if (stateOpen) {                            //逻辑:转给sToken(sFISH),用剩下的钱买FISH打到sToken里面作为奖励
            (uint256 reserve0, uint256 reserve1, ) = IUniswapV2Pair(pairAddress)
                .getReserves();
            (reserve0, reserve1) = address(USDC) == token0
                ? (reserve0, reserve1)
                : (reserve1, reserve0);             //计算出来USDC对应reserve0还是reserve1,FISH对应reserve0还是reserve1
            uint256 amountFish = getAmountOut(
                amountUSDCToSFISH,                  //用amountUSDCToSFISH(USDC)去买FISH,可以买多少,预先算的
                reserve0,
                reserve1
            );
            (uint256 amount0Out, uint256 amount1Out) = address(USDC) == token0   //因为要用USDC去买FISH,所以要判断,出来是0的就是USDC
                ? (uint256(0), amountFish)
                : (amountFish, uint256(0));
            USDC.safeTransfer(address(pairAddress), amountUSDCToSFISH);         //把钱打给LP合约
            IUniswapV2Pair(pairAddress).swap(
                amount0Out,
                amount1Out,
                address(this),
                new bytes(0)
            );                                                                 //uniswap的一个安全的交易方法,可以很好的控制好滑点
            IERC20Upgradeable(address(FISH)).safeTransfer(
                address(sFISH),
                IERC20Upgradeable(address(FISH)).balanceOf(address(this))
            );                                                              //查询FISH有多少然后直接转给sFISH合约
        } else {
            USDC.safeTransfer(
                address(multiSignatureToSToken),
                amountUSDCToSFISH
            );
        }

        (, uint256 rate) = updateExchangeRate();   //如果交易成功,FISH的价格就会发生变化,否则不会变

        updateRoi();                                //自己设置的,买一个ROI是下降还是上升,可以控制能卖多少张,没卖一张收益下降多少

        for (uint256 i = 0; i < amt; i++) {
            FISHNFT.mintFromExecutor(
                msg.sender,
                block.timestamp + i,
                (((price * rate) / 1e18) * (ROI + PRECISION)) / PRECISION
            );
        }
        return true;

    }

    function calAndSwap(
        IUniswapV2Pair lpToken,
        address tokenA,
        address tokenB,
        uint256 amountUSDCToLiquidity
    ) internal {
        (uint256 token0Reserve, uint256 token1Reserve, ) = lpToken
            .getReserves();
        (uint256 debtReserve, uint256 relativeReserve) = address(FISH) ==
            lpToken.token0()
            ? (token0Reserve, token1Reserve)
            : (token1Reserve, token0Reserve);
        (uint256 swapAmt, bool isReversed) = optimalDeposit(
            0,
            amountUSDCToLiquidity,
            debtReserve,
            relativeReserve
        );

        if (swapAmt > 0) {
            address[] memory path = new address[](2);
            (path[0], path[1]) = isReversed
                ? (tokenB, tokenA)
                : (tokenA, tokenB);
            Router.swapExactTokensForTokens(
                swapAmt,
                0,
                path,
                address(this),
                block.timestamp
            );
        }
    }

    function optimalDeposit(
        uint256 amtA,
        uint256 amtB,
        uint256 resA,
        uint256 resB
    ) internal pure returns (uint256 swapAmt, bool isReversed) {
        if (amtA.mul(resB) >= amtB.mul(resA)) {
            swapAmt = _optimalDepositA(amtA, amtB, resA, resB);
            isReversed = false;
        } else {
            swapAmt = _optimalDepositA(amtB, amtA, resB, resA);
            isReversed = true;
        }
    }

    function _optimalDepositA(
        uint256 amtA,
        uint256 amtB,
        uint256 resA,
        uint256 resB
    ) internal pure returns (uint256) {
        require(amtA.mul(resB) >= amtB.mul(resA), "Reversed");

        uint256 a = 997;
        uint256 b = uint256(1997).mul(resA);
        uint256 _c = (amtA.mul(resB)).sub(amtB.mul(resA));
        uint256 c = _c.mul(1000).div(amtB.add(resB)).mul(resA);

        uint256 d = a.mul(c).mul(4);
        uint256 e = Math.sqrt(b.mul(b).add(d));

        uint256 numerator = e.sub(b);
        uint256 denominator = a.mul(2);

        return numerator.div(denominator);
    }

    //以上三个合约是计算用的,

}


