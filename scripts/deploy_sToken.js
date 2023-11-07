const { ethers, upgrades } = require("hardhat");


function sleep(time) {
    return new Promise((resolve) => setTimeout(resolve, time));
}

const contracts = {// test
    token: '0x37E1103c1244a66C2ABfb6e81dfD1Ee0EB0811b4',
    sToken: '0x545eBe05f67cF529E142e45785fEB538Ae0eA3E5',
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


    const SToken = await ethers.getContractFactory('sTokenERC20');
    if (contracts.sToken) {
        var sToken = SToken.attach(contracts.sToken);
    } else {
        sToken = await SToken.deploy(contracts.token);
        // sToken = await upgrades.deployProxy(SToken, ['sToken', 'sToken'], { initializer: 'initialize' });
        // await sToken.deployed();
    }
    contracts.sToken = sToken.address;
    console.log("sToken:", contracts.sToken);


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



