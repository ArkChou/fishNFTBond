const { ethers, upgrades } = require("hardhat");


function sleep(time) {
    return new Promise((resolve) => setTimeout(resolve, time));
}



const contracts = {
    pancakeRouter: '0x02133C88D209f2660Aec19de360D3dd8DC104d4E',   //自己的路由地址  WAVAX:0xfaf7AE6c055Da36b527A9F5Fd4D9821877EAc3AE
    pancakeFactory: '0x2C660395d60E68b51B90269EC559fFA84C90A0f4',  //自己的工厂地址  WTEST:0x249C88461fd282bfa7f1506AC2715991e7e838C8
    multiSignature: '0xE51be038eeBDD8067E3D2a83916F5C6d45e079d0',   //多签地址   账户2
    multiSignatureToSToken: '0xB0C868D46921fea4d57d19D1B3ea1D03BEc1a377',   //如果没有开启活动钱打入这个多签地址   账户3
    usdc: '0xc468707cdDd55495F8e7C5ba05114db894455be1',  //部署的
    fish: '0xF2c8Cde012DC9d8a580A278fda13509DF1585Ae1',  //部署的   在PancakeRouter里面用作_WETH
    fishOracle: '0xaf74A900a1D1BCEf137EA9bD4Ef8Fa9Df6cb5810',
    sFISH: '0xab8C3236F54799C85f6E17504d5dFB68dEA58CcD',
    dev: '0xE51be038eeBDD8067E3D2a83916F5C6d45e079d0',   //Account2
    op: '0xB0C868D46921fea4d57d19D1B3ea1D03BEc1a377',    //Account3
    usdc_fish_lp: '0xbC33216a0274C5710fa3b68631305540a73D1f8a',
    fishNft: '0xdbD620b41fF093B9860Cc2A5763E74DA66d22845',
    usdcBuyNftLogic: ''
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
    * UsdcBuyNftLogic
    */
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

    // //设置执行者
    // await contracts.fish.setExecutor(contracts.usdcBuyNftLogic, true); console.log("fish.setExecutor");
    // await contracts.fishNft.setExecutor(contracts.usdcBuyNftLogic, true); console.log("fishNft.setExecutor");


    // //approve usdcBuyNftLogic 测试买入用
    // await contracts.usdc.approve(contracts.usdcBuyNftLogic, '1000000000000000000000000000000'); console.log("usdc.approve:usdcBuyNftLogic");


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


