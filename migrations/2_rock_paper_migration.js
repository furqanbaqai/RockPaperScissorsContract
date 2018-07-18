var RockPaperScissors = artifacts.require("./RockPaperScissors.sol");

module.exports = function (deployer, accounts) {
    deployer.deploy(RockPaperScissors);
};
