const { ethers, upgrades } = require("hardhat");


function sleep(time) {
    return new Promise((resolve) => setTimeout(resolve, time));
}

const contracts = {// test
    token: '',
    aToken: '0xF9c2C1d6F3bf243DFd6353b09fcA983585b3a96a',
    claim: ''
}


async function main() {
    const [deployer] = await ethers.getSigners();

    var now = Math.round(new Date() / 1000);
    console.log('部署人：', deployer.address);


    const Token = await ethers.getContractFactory('proxyERC20');
    if (contracts.token) {
        var token = Token.attach(contracts.token);
    } else {
        token = await upgrades.deployProxy(Token, ['token', 'token'], { initializer: 'initialize' });
        await token.deployed();
    }
    contracts.token = token.address;
    console.log("token:", contracts.token);
    await token.setExecutor(deployer.address, true); console.log("setExecutor "); await sleep(5000);
    await token.mint(deployer.address, '1000000000000000000000000000000'); console.log("mint "); await sleep(5000);
    console.log('token部署完成-----------------------')


    const AToken = await ethers.getContractFactory('proxyERC20');
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


    const Claim = await ethers.getContractFactory('claim');
    if (contracts.claim) {
        var claim = Claim.attach(contracts.claim);
    } else {
        claim = await upgrades.deployProxy(Claim, [
            contracts.token,
            contracts.aToken,
            '1689512775',
            '1692261693'
        ], { initializer: 'initialize' });
        await claim.deployed();
    }
    contracts.claim = claim.address;
    console.log("claim:", contracts.claim);

    await token.approve(contracts.claim, '1000000000000000000000000000000'); console.log("approve "); await sleep(5000);
    await aToken.approve(contracts.claim, '1000000000000000000000000000000'); console.log("approve "); await sleep(5000);

    await token.transfer(contracts.claim, '1000000000000000000000000000000'); console.log("transfer "); await sleep(5000);
 

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

    //npx hardhat run --network fuji scripts/deploy_claim.js

    //contracts: {
//   token: '0x8fA54BF02C76625205aB6538d5B2531939eaA87f',
//   aToken: '0xF9c2C1d6F3bf243DFd6353b09fcA983585b3a96a',
//   claim: '0x4e1bb90b89c73C13D912963c1723D411EbC3Ba04'
// }

