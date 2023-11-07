const { ethers, upgrades } = require("hardhat");


function sleep(time) {
    return new Promise((resolve) => setTimeout(resolve, time));
}



const contracts = {
    pancakeRouter: '0x02133C88D209f2660Aec19de360D3dd8DC104d4E',   //自己的路由地址  WAVAX:0xfaf7AE6c055Da36b527A9F5Fd4D9821877EAc3AE
    pancakeFactory: '0x2C660395d60E68b51B90269EC559fFA84C90A0f4',  //自己的工厂地址  WTEST:0x249C88461fd282bfa7f1506AC2715991e7e838C8
    multiSignature: '0xE51be038eeBDD8067E3D2a83916F5C6d45e079d0',   //多签地址  2
    multiSignatureToSToken: '0x834dc27878FAe4c110660d72a70f181050Ac3340',   //如果没有开启活动钱打入这个多签地址  4
    usdc: '0xBf345350b4B7dC44f1c733FcBb14060b79A8c742',  //部署的
    fish: '0x5f5a2250E0594dd1147b128d7bec91F885608cE3',  //部署的   在PancakeRouter里面用作_WETH
    fishOracle: '0xd236949341602AE0fdBB3ad5E306D1668bD76322',
    sFISH: '0x0030AD2Da3E525cd369745D05ECcf42B9b48925b',
    dev: '0x79A7d0DC19e47ef2A8BBD51df933BB2a52095152',   //Account4
    op: '0x79A7d0DC19e47ef2A8BBD51df933BB2a52095152',    //Account2
    usdc_fish_lp: '0x4363C710Ab9fE07eec056c9c1A9B47541Ac518d2',
    fishNft: '0x0E56F3ab68Ed39CA2d4E1e39F7C0B2bd6997d114',
    usdcBuyNftLogic: '0xC7CA7a5e12B5175bA016bCE5AFB2c79F1075f28d'  //后面部署的
}


async function main() {
    const [deployer] = await ethers.getSigners();

    var now = Math.round(new Date() / 1000);
    contracts.dev = deployer.address;
    contracts.op = deployer.address;
    console.log('部署人：', deployer.address);

    const PancakeRouter = await ethers.getContractFactory('PancakeRouter');
    const pancakeRouter = PancakeRouter.attach(contracts.pancakeRouter);
    const PancakeFactory = await ethers.getContractFactory('PancakeFactory');
    const pancakeFactory = PancakeFactory.attach(contracts.pancakeFactory);

    /**
     * 假USDC ERC20 (实盘不需要)
     */
    const USDCERC20 = await ethers.getContractFactory('FishERC20');
    if (contracts.usdc) {
        var usdc = USDCERC20.attach(contracts.usdc);
    } else {
        usdc = await upgrades.deployProxy(USDCERC20, ['USDC-test', 'USDC-test', deployer.address, '100000000000000000000000000'], { initializer: 'initialize' });
        await usdc.deployed();
    }
    contracts.usdc = usdc.address;
    console.log("usdc:", contracts.usdc);


    /**
     * FishERC20
     */
    const FishERC20 = await ethers.getContractFactory('FishERC20');
    if (contracts.fish) {
        var fish = FishERC20.attach(contracts.fish);
    } else {
        fish = await upgrades.deployProxy(FishERC20, ['Fish Token', 'FISH', deployer.address, '100000000000000000'], { initializer: 'initialize' });
        await fish.deployed();
    }
    contracts.fish = fish.address;
    console.log("fish:", contracts.fish);

    /**
     * 组流动性 
     */
    await pancakeFactory.createPair(fish.address, usdc.address);
    await sleep(10000);
    var usdc_fish_lp_address = await pancakeFactory.getPair(fish.address, usdc.address);
    console.log("usdc_fish_lp_address:", usdc_fish_lp_address);
    contracts.usdc_fish_lp = usdc_fish_lp_address;
    await usdc.approve(contracts.pancakeRouter, '1000000000000000000000000000000'); console.log("usdc.approve:");
    await fish.approve(contracts.pancakeRouter, '1000000000000000000000000000000'); console.log("fish.approve:");
    await pancakeRouter.addLiquidity(
        fish.address,
        usdc.address,
        '100000000000000000',//0.1 fish
        '1500000000000000000',//1.5u
        0,
        0,
        deployer.address,
        Math.round(new Date() / 1000) + 1000
    );
    console.log("addLiquidity");

    /**
     * FISHOracle
     */
    await sleep(10000);
    const FISHOracle = await ethers.getContractFactory('FISHOracle');
    if (contracts.fishOracle) {
        var fishOracle = FISHOracle.attach(contracts.fishOracle);
    } else {
        fishOracle = await upgrades.deployProxy(FISHOracle, [usdc_fish_lp_address, contracts.fish], { initializer: 'initialize' });
        await fishOracle.deployed();
    }
    await fishOracle.get('0x0000000000000000000000000000000000000000'); console.log("get:");
    contracts.fishOracle = fishOracle.address;
    console.log("fishOracle:", contracts.fishOracle);
    /**
     * sFISH
     */
    await sleep(10000);
    const SFISH = await ethers.getContractFactory('sFISH');
    if (contracts.sFISH) {
        var sFISH = SFISH.attach(contracts.sFISH);
    } else {
        sFISH = await SFISH.deploy(fish.address);
        //定价
        await fish.approve(sFISH.address, '1000000000000000000000000000000'); console.log("fish.approve:sFISH");
        await fish.setExecutor(deployer.address, true); console.log("fish.setExecutor deployer.address");
        await fish.mint(deployer.address, '1000000000000000000');
        await sFISH.mint('1000000000000000000'); console.log("sFISH.mint");
    }
    contracts.sFISH = sFISH.address;
    console.log("sFISH:", contracts.sFISH);





    /**
     * fishNFT FishNft
     */
    await sleep(10000);
    const FishNft = await ethers.getContractFactory('FishNft');
    if (contracts.fishNft) {
        var fishNft = FishNft.attach(contracts.fishNft);
    } else {
        fishNft = await upgrades.deployProxy(FishNft, ["0xFishBone Nft", 'FB-NFT', contracts.fish], { initializer: 'initialize' });
        await fishNft.deployed();
    }
    contracts.fishNft = fishNft.address;
    console.log("fishNft:", contracts.fishNft);

    /**
    * UsdcBuyNftLogic
    */
    await sleep(10000);
    const UsdcBuyNftLogic = await ethers.getContractFactory('usdcBuyNftLogic');
    if (contracts.usdcBuyNftLogic) {
        var usdcBuyNftLogic = UsdcBuyNftLogic.attach(contracts.usdcBuyNftLogic);
    } else {
        usdcBuyNftLogic = await upgrades.deployProxy(UsdcBuyNftLogic, [
            contracts.fish,
            contracts.fishNft,
            contracts.pancakeFactory,
            contracts.pancakeRouter,
            contracts.multiSignature,
            contracts.multiSignatureToSToken,
            contracts.dev,
            contracts.op,
            contracts.sFISH,
            contracts.fishOracle,
            contracts.usdc], { initializer: 'initialize' });
        await usdcBuyNftLogic.deployed();
    }

    contracts.usdcBuyNftLogic = usdcBuyNftLogic.address;
    console.log("usdcBuyNftLogic:", contracts.usdcBuyNftLogic);

    //设置执行者
    await fish.setExecutor(contracts.fishNft, true); console.log("fish.setExecutor");
    await fish.setExecutor(contracts.usdcBuyNftLogic, true); console.log("fish.setExecutor");
    await fishNft.setExecutor(contracts.usdcBuyNftLogic, true); console.log("fishNft.setExecutor");


    //approve usdcBuyNftLogic 测试买入用
    await usdc.approve(contracts.usdcBuyNftLogic, '1000000000000000000000000000000'); console.log("usdc.approve:usdcBuyNftLogic");


    console.log("////////////////////全部合约//////////////////////");
    console.log("contracts:", contracts);
    console.log("/////////////////////END/////////////////////");




}

main()
    .then(() => process.exit())
    .catch(error => {
        console.error(error);
        process.exit(1);
    })

//npx hardhat run --network fuji scripts/deploy_fuji.js


