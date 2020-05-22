const OptionsManager = artifacts.require("OptionsManager");
const BalanceMapping = artifacts.require("BalanceMapping");
module.exports = function(deployer) {
    deployer.deploy(BalanceMapping);
    deployer.link(BalanceMapping,OptionsManager);
    deployer.deploy(OptionsManager);
};
