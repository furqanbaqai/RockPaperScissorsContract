var PlayerFundsManager = artifacts.require("./PlayerFundsManager.sol");

module.exports = function (deployer, accounts) {
    deployer.deploy(PlayerFundsManager, {
        gas: 600000,
        gasvalue: 1
    });
};
