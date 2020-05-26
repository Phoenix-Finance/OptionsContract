const OptionsManager = artifacts.require("OptionsManager");
module.exports = function(deployer) {
    deployer.deploy(OptionsManager);
};
