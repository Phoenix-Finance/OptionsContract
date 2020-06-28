const TestCompoundOracle = artifacts.require("TestCompoundOracle");
const OptionsFormulas = artifacts.require("OptionsFormulas");
const OptionsManager = artifacts.require("OptionsManager");
let MatchMakingTrading = artifacts.require("MatchMakingTrading");

module.exports = async function(deployer) {
    await deployer.deploy(TestCompoundOracle);
    await deployer.deploy(OptionsFormulas);
    let manager = await deployer.deploy(OptionsManager);
    let market = await deployer.deploy(MatchMakingTrading);
    console.log(TestCompoundOracle.address,OptionsFormulas.address,OptionsManager.address,MatchMakingTrading.address);
    await manager.setOracleAddress(TestCompoundOracle.address);
    await manager.setFormulasAddress(OptionsFormulas.address);
    await market.setOptionsManagerAddress(OptionsManager.address);
    await market.setOracleAddress(TestCompoundOracle.address);
};
