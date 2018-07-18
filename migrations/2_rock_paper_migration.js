var RockPaperScissors = artifacts.require("./RockPaperScissors.sol");

module.exports = function (deployer, accounts) {
     deployer.deploy(RockPaperScissors, {
         gas: 600000,
         gasvalue: 1
     });
};
