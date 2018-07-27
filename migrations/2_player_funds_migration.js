var PlayerFundsManager = artifacts.require("./PlayerFundsManager.sol");
var RockPaperScissors = artifacts.require("./RockPaperScissors.sol");

module.exports = function (deployer, accounts) {
    deployer.deploy(PlayerFundsManager, {
        gas: 1000000,
        gasvalue: 1
    }).then(function () {
        return deployer.deploy(RockPaperScissors, PlayerFundsManager.address, {
            gas: 1100000,
            gasvalue: 1
        });
    });;
};
