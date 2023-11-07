const { ethers, upgrades } = require("hardhat");


function sleep(time) {
    return new Promise((resolve) => setTimeout(resolve, time));
}

const contracts = {// test
    testUSDC: '',
    aToken: '',
    whiteList: ''
}



async function main() {
    const [deployer] = await ethers.getSigners();

    var now = Math.round(new Date() / 1000);
    console.log('部署人：', deployer.address);

    const USDCERC20 = await ethers.getContractFactory('proxyERC20');
    // testUSDC = await USDCERC20.deploy('nameToken', 'NAME');
    if (contracts.testUSDC) {
        var testUSDC = USDCERC20.attach(contracts.testUSDC);
    } else {
        testUSDC = await upgrades.deployProxy(USDCERC20, ['USDC-test', 'USDC-test'], { initializer: 'initialize' });
        await testUSDC.deployed();
    }
    contracts.testUSDC = testUSDC.address;
    console.log("usdc:", contracts.testUSDC);
    await testUSDC.setExecutor(deployer.address, true); console.log("setExecutor "); await sleep(5000);
    await testUSDC.mint(deployer.address, '1000000000000000000000000000000'); console.log("mint "); await sleep(5000);


    const AToken = await ethers.getContractFactory('proxyERC20');
    // testUSDC = await AToken.deploy('nameToken', 'NAME');
    if (contracts.aToken) {
        var aToken = AToken.attach(contracts.aToken);
    } else {
        aToken = await upgrades.deployProxy(AToken, ['aToken', 'aToken'], { initializer: 'initialize' });
        await aToken.deployed();
    }
    contracts.aToken = aToken.address;
    console.log("aToken:", contracts.aToken);
    await aToken.setExecutor(deployer.address, true); console.log("setExecutor "); await sleep(5000);
    await aToken.mint(deployer.address, '1000000000000000000000000000000'); console.log("mint "); await sleep(5000);


    const WhiteList = await ethers.getContractFactory('whiteList');
    if (contracts.whiteList) {
        var whiteList = WhiteList.attach(contracts.whiteList);
    } else {
        whiteList = await upgrades.deployProxy(WhiteList, [
            '0x7606aBe5D1D28f21310348C8A4e5d32aF99a844c',
            contracts.aToken,
            contracts.testUSDC,
            '0',
            '10000000000000000000000',
            '100000000000000000000000000',
            '500000000000000000',
            '1689069480',
            '1692261693'
        ], { initializer: 'initialize' });
        await whiteList.deployed();
    }
    contracts.whiteList = whiteList.address;
    console.log("whiteList:", contracts.whiteList);

    await testUSDC.approve(contracts.whiteList, '1000000000000000000000000000000'); console.log("approve "); await sleep(5000);
    await aToken.approve(contracts.whiteList, '1000000000000000000000000000000'); console.log("approve "); await sleep(5000);

    await aToken.transfer(contracts.whiteList, '1000000000000000000000000000000'); console.log("transfer "); await sleep(5000);


    console.log("////////////////////全部合约//////////////////////");
    console.log("contracts:", contracts);
    console.log("/////////////////////END/////////////////////");


    return;



}

main()
    .then(() => process.exit())
    .catch(error => {
        console.error(error);
        process.exit(1);
    })

    //npx hardhat run --network fuji scripts/deploy.js
    

        //npx hardhat run --network fuji scripts/deploy_claim.js
    /**
     * 部署人： 0x79A7d0DC19e47ef2A8BBD51df933BB2a52095152
usdc: 0xb4ACC9980FD034D8f53e6515B631d2C5f91008e0
setExecutor 
mint 
aToken: 0x4Cd53A7b3EdB0D69229Cf670d569E6994CfB0a09
setExecutor 
mint 
whiteList: 0x00126704951a11ABB68b689615b7c20D29C41458
approve 
approve 
transfer 
////////////////////全部合约//////////////////////
contracts: {
  testUSDC: '0x4ce9C56FeaeedA0a3107f4A1A4EFa2ba25fa9859',
  aToken: '0xF9c2C1d6F3bf243DFd6353b09fcA983585b3a96a',
  whiteList: '0x7911A2ce79bcdB98350F765dfF6B0b4218072d32'
}
     */




