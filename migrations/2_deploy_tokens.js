const BLUECoin = artifacts.require(`./BLUECoin.sol`)
const BLUEScan = artifacts.require(`./BLUEScan.sol`)

module.exports = (deployer) => {
  deployer.deploy(BLUECoin);
  deployer.deploy(BLUEScan);
}
