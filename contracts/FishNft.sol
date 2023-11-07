// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
interface IFISH {
    function mint(address account_, uint256 amount_) external returns (bool);
}

library Random {
    /**
     * Initialize the pool with the entropy of the blockhashes of the blocks in the closed interval [earliestBlock, latestBlock]
     * The argument "seed" is optional and can be left zero in most cases.
     * This extra seed allows you to select a different sequence of random numbers for the same block range.
     */
    function init(
        uint256 earliestBlock,
        uint256 latestBlock,
        uint256 seed
    ) internal view returns (bytes32[] memory) {
        //require(block.number-1 >= latestBlock && latestBlock >= earliestBlock && earliestBlock >= block.number-256, "Random.init: invalid block interval");
        require(
            block.number - 1 >= latestBlock && latestBlock >= earliestBlock,
            "Random.init: invalid block interval"
        );
        bytes32[] memory pool = new bytes32[](latestBlock - earliestBlock + 2);
        bytes32 salt = keccak256(abi.encodePacked(block.number, seed));
        for (uint256 i = 0; i <= latestBlock - earliestBlock; i++) {
            // Add some salt to each blockhash so that we don't reuse those hash chains
            // when this function gets called again in another block.
            pool[i + 1] = keccak256(
                abi.encodePacked(blockhash(earliestBlock + i), salt)
            );
        }
        return pool;
    }

    /**
     * Initialize the pool from the latest "num" blocks.
     */
    function initLatest(uint256 num, uint256 seed)
        internal
        view
        returns (bytes32[] memory)
    {
        return init(block.number - num, block.number - 1, seed);
    }

    /**
     * Advances to the next 256-bit random number in the pool of hash chains.
     */
    function next(bytes32[] memory pool) internal pure returns (uint256) {
        require(pool.length > 1, "Random.next: invalid pool");
        uint256 roundRobinIdx = (uint256(pool[0]) % (pool.length - 1)) + 1;
        bytes32 hash = keccak256(abi.encodePacked(pool[roundRobinIdx]));
        pool[0] = bytes32(uint256(pool[0]) + 1);
        pool[roundRobinIdx] = hash;
        return uint256(hash);
    }

    /**
     * Produces random integer values, uniformly distributed on the closed interval [a, b]
     */
    function uniform(
        bytes32[] memory pool,
        int256 a,
        int256 b
    ) internal pure returns (int256) {
        require(a <= b, "Random.uniform: invalid interval");
        return int256(next(pool) % uint256(b - a + 1)) + a;
    }
}

contract FishNft is Initializable,ERC721EnumerableUpgradeable,OwnableUpgradeable{
        using SafeERC20Upgradeable for IERC20Upgradeable;
        using SafeMath for uint256;

        mapping (address => bool) public executor;
        
        uint256 public tokenIdIndex;  //因为是吞噬行的NFT，所以自己创建索引
        string public _baseURI_;      //图片的uri地址
        address public FISH;          //FISH币的地址
        uint256 public maxPreSale;    //最大的销售量
        uint256 public preSaleEnd;    //销售的结束时间
        bool public stateOpen;        //整个协议的状态（如果是false，就说明项目还没有开始，就不允许去进行一个销毁获取奖励）
    
        struct UserInfo{
            uint256 lastClaimTimestamp;  //上一次claim 的时间
            uint256 releaseSecond;  //奖励释放的时间，按秒算
            uint256 claimble;       //可领的奖励
        }

        struct NftInfo{
            string fishStr;  //nft的样式
            uint256 remainingReward;  //里面有多少奖励，一般创建出来奖励就是恒定的；
            uint256 lv;     //等级
            uint256 random; //随机数，可以当作一个备用的数，后期需要加什么皮肤就可以用这个去锚定
        }

        mapping (uint256 => uint256) public releaseCycle;  //释放的一个周期
        mapping (uint256 => NftInfo) public _nftInfo;
        mapping (address => UserInfo) internal _userInfo;

        function initialize(
        string memory _name,
        string memory _symbol,
        address _FISH
    ) external initializer {
        FISH = _FISH;        //平台币地址
        maxPreSale = 1000;   //最大销售额
        stateOpen = false;   //是否开启可以销毁释放领取奖励
        __ERC721_init(_name, _symbol);  //nft的名字和简称
        __Ownable_init();
        executor[msg.sender] = true;
        releaseCycle[0] = 14 days;      //等级0的释放周期是14days；
        releaseCycle[1] = 10 days;
        releaseCycle[2] = 5 days;
        // tokenLimit = 9999;
    }

    modifier onlyExecutor() {
        require(executor[msg.sender],"executor: caller is not the executor");
        _;
    }

    function nftInfo(uint256 _id) external view returns (NftInfo memory) {
        return _nftInfo[_id];
    }

    function setNftInfo(
        uint256 i,
        string memory str,
        uint256 _remainingReward,
        uint256 _lv,
        uint256 _random
    ) public onlyExecutor returns (bool) {
        return _setNftInfo(i, str, _remainingReward, _lv, _random);
    }

    function _setNftInfo(
        uint256 i,
        string memory str,
        uint256 _remainingReward,
        uint256 _lv,
        uint256 _random
    ) internal returns (bool) {
        _nftInfo[i] = NftInfo({
            fishStr: str,
            remainingReward: _remainingReward,
            lv: _lv,
            random: _random
        });
        return true;
    }

    function userInfo(address _user) external view returns (UserInfo memory) {
        return _userInfo[_user];
    }

    function setUserInfo(
        address _user,
        uint256 _lastClaimTimestamp,
        uint256 _releaseSecond,
        uint256 _claimble
    ) public onlyExecutor returns (bool) {
        return
            _setUserInfo(_user, _lastClaimTimestamp, _releaseSecond, _claimble);
    }

    function _setUserInfo(
        address _user,
        uint256 _lastClaimTimestamp,
        uint256 _releaseSecond,
        uint256 _claimble
    ) internal returns (bool) {
        _userInfo[_user] = UserInfo({
            lastClaimTimestamp: _lastClaimTimestamp,
            releaseSecond: _releaseSecond,
            claimble: _claimble
        });
        return true;
    }

    function setReleaseCycle(uint256 _lv, uint256 _releaseSecond)
        public
        onlyOwner
        returns (bool)
    {
        releaseCycle[_lv] = _releaseSecond;
        return true;
    }   //设置哪个等级的释放周期


    function setStateOpen(bool _bool) public onlyOwner returns (bool) {
        stateOpen = _bool;
        return true;
    }   //自己设置什么时候开始

    function setBaseURI(string memory _str) public onlyOwner returns (bool) {
        _baseURI_ = _str;
        return true;
    }   //如果域名被黑或者换域名可以设置

    function setMaxPreSale(uint256 _val) public onlyOwner returns (bool) {
        maxPreSale = _val;
        return true;
    }  //设置一个最大发行量

    function setPreSaleEnd(uint256 _val) public onlyOwner returns (bool) {
        preSaleEnd = _val;
        return true;
    }  //销售结束时间

    function setExecutor(address _address, bool _type)
        external
        onlyOwner
        returns (bool)
    {
        executor[_address] = _type;
        return true;
    }

    function getLvPoint(uint256 seed) internal view returns (uint256 lv) {
        bytes32[] memory pool = Random.initLatest(3, seed);

        uint256 RNG = uint256(Random.uniform(pool, 1, 100));

        if (RNG <= 60) {
            lv = 0;
        } else if (RNG <= 90) {
            lv = 1;
        } else {
            lv = 2;
        }
    }

    //-----------------------------以下就是创建NFT的fuction，真正的逻辑合约的地方--------------------------------
    function getFishBodyPoint(uint256 seed)
        internal
        view
        returns (uint256 ret)
    {
        bytes32[] memory pool = Random.initLatest(10, seed);

        uint256 RNG = uint256(Random.uniform(pool, 1, 100));

        if (RNG <= 10) {
            ret = 0;
        } else if (RNG <= 20) {
            ret = 1;
        } else if (RNG <= 30) {
            ret = 2;
        } else if (RNG <= 40) {
            ret = 3;
        } else if (RNG <= 50) {
            ret = 4;
        } else if (RNG <= 60) {
            ret = 5;
        } else if (RNG <= 70) {
            ret = 6;
        } else if (RNG <= 80) {
            ret = 7;
        } else if (RNG <= 90) {
            ret = 8;
        } else {
            ret = 9;
        }
    }

    function createFish(address _to,uint256 seed,uint256 _remainingReward) internal returns(bool){
        string[10] memory fishBodys = [
            "|",
            "#",
            "(",
            ")",
            "!",
            "]",
            "$",
            "[",
            "+",
            "&"
        ];

        uint256 fishBodysID1 = getFishBodyPoint(seed + 1 + totalSupply());
        uint256 fishBodysID2 = getFishBodyPoint(seed + 2 + totalSupply());
        uint256 fishBodysID3 = getFishBodyPoint(seed + 3 + totalSupply());
        uint256 fishBodysID4 = getFishBodyPoint(seed + 4 + totalSupply());
        uint256 fishBodysID5 = getFishBodyPoint(seed + 5 + totalSupply());

        string memory fishAssembly = string(
            abi.encodePacked(
                "<",
                "\u00b0", //"°"   鱼头
                fishBodys[fishBodysID1],
                fishBodys[fishBodysID2],
                fishBodys[fishBodysID3],
                fishBodys[fishBodysID4],
                fishBodys[fishBodysID5],
                "\u2264" //"≤"    鱼尾
            )
        );

        bytes32[] memory pool = Random.initLatest(8, seed);
        uint256 backupPoint = uint256(Random.uniform(pool, 1, 10000));

        uint256 lv = getLvPoint(seed);
        _registerToken(_to, fishAssembly, _remainingReward, lv, backupPoint);
        return true;
    }

    function _registerToken(
        address _to,
        string memory _fishAssembly,
        uint256 _remainingReward,
        uint256 _lv,
        uint256 _backupPoint
    ) internal returns (bool) {
        _setNftInfo(
            tokenIdIndex,
            _fishAssembly,
            _remainingReward,
            // releaseCycle[_lv],
            _lv,
            _backupPoint
        );

        super._safeMint(_to, tokenIdIndex);
        tokenIdIndex = tokenIdIndex.add(1);
        return true;
    }

    function integerToString(uint256 _i) internal pure returns (string memory) {
        if (_i == 0) {
            return "0";
        }
        uint256 temp = _i;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (_i != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(_i % 10)));
            _i /= 10;
        }
        return string(buffer);
    }   //把数字变成字符串

    function mintFromExecutor(address _to,uint256 seed,uint256 _remainingReward) external onlyExecutor returns (bool){
        require(executor[msg.sender],"executor is not good");
        return createFish(_to, seed, _remainingReward);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        require(
            _exists(tokenId),
            "ERC721URIStorage: URI query for nonexistent token"
        );
        return string(abi.encodePacked(_baseURI_, integerToString(tokenId)));
    }

    function burn(uint256 _id) external returns (bool) {
        require(msg.sender == ownerOf(_id), "No approved");  
        checkState();
        UserInfo storage user = _userInfo[msg.sender];
        user.lastClaimTimestamp = block.timestamp;
        user.releaseSecond = releaseCycle[_nftInfo[_id].lv];
        user.claimble = user.claimble.add(_nftInfo[_id].remainingReward);

        super._burn(_id);
        return true;
    }

    function burnFrom(address _user, uint256 _id)
        external
        onlyExecutor
        returns (bool)
    {
        require(_user == ownerOf(_id), "No approved");  //检查使用者是不是这个nft的拥有者
        checkState();
        UserInfo storage user = _userInfo[_user];   //加了storage,后面的user.方法改变的值就会在mapping里面改变,而不用再重新调用set方法区改
        user.lastClaimTimestamp = block.timestamp;
        user.releaseSecond = releaseCycle[_nftInfo[_id].lv];
        user.claimble = user.claimble.add(_nftInfo[_id].remainingReward);  //本来我拥有的奖励加上释放nft后应该获得的奖励

        super._burn(_id);
        return true;
    }

    function checkState() internal view returns (bool) {
        require(stateOpen, "Please wait for the agreement to start");   //一个开关,是否开启活动
        if (maxPreSale <= totalSupply() || block.timestamp >= preSaleEnd) {  //最大销售量没有超过总量并且却快时间大于结束时间
            return true;
        } else {
            require(
                false,
                "The sales time has not ended or the totalSupply quantity has not reached the target"
            );
        }
        return false;
    }

    function pending() external view returns (uint256) {
        UserInfo storage user = _userInfo[msg.sender];
        uint256 diffTimestamp = block.timestamp.sub(user.lastClaimTimestamp);
        if (diffTimestamp >= user.releaseSecond) {
            return user.claimble;
        } else {
            return diffTimestamp.mul(user.claimble).div(user.releaseSecond);
        }
    }

    function claim() external returns (bool) {
        UserInfo storage user = _userInfo[msg.sender];
        require(user.claimble > 0, "claimble is 0");
        uint256 diffTimestamp = block.timestamp.sub(user.lastClaimTimestamp);
        if (diffTimestamp >= user.releaseSecond) {
            IFISH(FISH).mint(msg.sender, user.claimble);
            user.lastClaimTimestamp = block.timestamp;
            user.claimble = 0;
            user.releaseSecond = 0;
        } else {
            uint256 _pending = diffTimestamp.mul(user.claimble).div(
                user.releaseSecond
            );
            IFISH(FISH).mint(msg.sender, _pending);
            user.lastClaimTimestamp = block.timestamp;
            user.claimble = user.claimble.sub(_pending);
            user.releaseSecond = user.releaseSecond.sub(diffTimestamp);
        }
        return true;
    }
}
