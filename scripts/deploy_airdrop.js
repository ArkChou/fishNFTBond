const { ethers, upgrades } = require("hardhat");


function sleep(time) {
    return new Promise((resolve) => setTimeout(resolve, time));
}

const contracts = {// test
    testUSDC: '0x22262e717B5F3Febf298C6dc128c23deFEB91add',
    airdrop: '0xaD64435719eC5a81D94A0a6FfD0Aede68b2ae7dB'
}

async function main() {
    const [deployer] = await ethers.getSigners();

    var now = Math.round(new Date() / 1000);
    console.log('部署人：', deployer.address);


    const USDCERC20 = await ethers.getContractFactory('proxyERC20');
    if (contracts.testUSDC) {
        var testUSDC = USDCERC20.attach(contracts.testUSDC);
    } else {
        testUSDC = await upgrades.deployProxy(USDCERC20, ['airdrop', 'airToken'], { initializer: 'initialize' });
        await testUSDC.deployed();
    }
    contracts.testUSDC = testUSDC.address;
    console.log("testUSDC:", contracts.testUSDC);
    await testUSDC.setExecutor(deployer.address, true); console.log("setExecutor "); await sleep(5000);
    await testUSDC.mint(deployer.address, '10000000000000000000000'); console.log("mint "); await sleep(5000);
    console.log('testUSDC部署完成-----------------------')


    const Airdrop = await ethers.getContractFactory('airdrop');
    if (contracts.airdrop) {
        var airdrop = Airdrop.attach(contracts.airdrop );
    } else {
        airdrop = await upgrades.deployProxy(Airdrop, [], { initializer: 'initialize' });
        await airdrop.deployed();
    }
    contracts.airdrop = airdrop.address;
    console.log("airdrop:", contracts.airdrop);
    // await airdrop.setExecutor(deployer.address, true); console.log("setExecutor "); await sleep(5000);

    await testUSDC.approve(contracts.airdrop, '100000000000000000000000'); console.log("approve "); await sleep(5000);
 

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
