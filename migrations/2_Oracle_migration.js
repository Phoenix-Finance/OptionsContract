const TestCompoundOracle = artifacts.require("TestCompoundOracle");

module.exports = function(deployer) {
  deployer.deploy(TestCompoundOracle);
};
