const expectThrow = require('./utils').expectThrow
const BLUECoinAbstraction = artifacts.require('BLUECoin')
const BLUEScanAbstraction = artifacts.require('BLUEScan')
let BCN
let BSC

contract('BLUEScan', function (accounts) {
    beforeEach(async () => {
        BSC = await BLUEScanAbstraction.new({ from: accounts[0] })
        BCN = await BLUECoinAbstraction.new({ from: accounts[0] })
    })

    it('admin add fail: not the owner', async () => {
        await expectThrow(BSC.addAuthorizedAdmin(accounts[1], { from: accounts[2] }));
    })

    it('admin add success: is the owner', async () => {
        await BSC.addAuthorizedAdmin(accounts[1], { from: accounts[0] });
    })

    it('add payment method fail: not an admin', async () => {
        await expectThrow(BSC.upsertPaymentMethod(BCN.address, "BLUECoin, best payment method", 1, 1, { from: accounts[1] }))
    })

    it('add payment method success: should add admin and allow new payment method', async () => {
        await BSC.addAuthorizedAdmin(accounts[1], { from: accounts[0]});
        var res = await BSC.upsertPaymentMethod(BCN.address, "BLUECoin, best payment method", 1, 1, { from: accounts[1] })
        var eventLog = res.logs.find(element => element.event.match('PaymentMethodUpdated'))
        assert.strictEqual(eventLog.args.paymentMethodAddress, BCN.address)
    })
    
    it('scan payment fail: should not allow a scan with unsupported payment methods', async () => {
        await expectThrow(BSC.scanAddressWithPayment(accounts[1], BCN.address, { from: accounts[0] }))
    })

    it('scan payment fail: not enough approval for given payment method', async () => {
        await BSC.addAuthorizedAdmin(accounts[0], { from: accounts[0] });
        // requires 2 blue
        await BSC.upsertPaymentMethod(BCN.address, "BLUECoin, best payment method", 2, 1, { from: accounts[0] })
        await BCN.approve(BSC.address, 1, { from: accounts[0] })
        // only 1 given so not enough
        await expectThrow(BSC.scanAddressWithPayment(accounts[1], BCN.address, { from: accounts[0] }))
    })

    it('scan payment fail: not enough of payment method', async () => {
        await BSC.addAuthorizedAdmin(accounts[0], { from: accounts[0] });
        await BSC.upsertPaymentMethod(BCN.address, "BLUECoin, best payment method", 9999999999, 1,  { from: accounts[0] })
        await BCN.approve(BSC.address, 9999999999, { from: accounts[1] })
        await expectThrow(BSC.scanAddressWithPayment(accounts[1], BCN.address, { from: accounts[1] }))
    })

    it('scan payment success: event emmited', async () => {
        await BSC.addAuthorizedAdmin(accounts[0], { from: accounts[0] });
        await BSC.upsertPaymentMethod(BCN.address, "BLUECoin, best payment method", 1, 1, { from: accounts[0] })
        var previousBalance = await BCN.balanceOf(accounts[0], { from: accounts[1]});
        await BCN.approve(BSC.address, 1, { from: accounts[0] })

        var res = await BSC.scanAddressWithPayment(accounts[1], BCN.address, { from: accounts[0] })
        var eventLog = res.logs.find(element => element.event.match('ScanRequested'))
        assert.strictEqual(eventLog.args.addressToScan, accounts[1])
        var newBalance = await BCN.balanceOf(accounts[0], { from: accounts[1] });
        assert.strictEqual(newBalance.toNumber(), previousBalance.toNumber() - 1);
    })

    it('add worker fail: not an admin', async () => {
        await expectThrow(BSC.addWorker(accounts[2], { from: accounts[0] }));
    })

    it('add worker success: is an admin', async () => {
        await BSC.addAuthorizedAdmin(accounts[0], { from: accounts[0] });
        await BSC.addWorker(accounts[2], { from: accounts[0] });
    })

    it('scan job fail: not a worker', async () => {
        expectThrow(BSC.getNextScanJob({ from: accounts[4] }));
    })

    it('scan job fail: worker without job', async () => {
        await BSC.addAuthorizedAdmin(accounts[0], { from: accounts[0] });
        await BSC.addWorker(accounts[2], { from: accounts[0] });
        expectThrow(BSC.getNextScanJob({ from: accounts[2] }));
    })

    it('scan payment result success: event emmited, result sent', async () => {
        await BSC.addAuthorizedAdmin(accounts[0], { from: accounts[0] });
        await BSC.upsertPaymentMethod(BCN.address, "BLUECoin, best payment method", 1, 1, { from: accounts[0] })
        var previousBalance = await BCN.balanceOf(accounts[0], { from: accounts[1] });
        await BCN.approve(BSC.address, 1, { from: accounts[0] })

        var res = await BSC.scanAddressWithPayment(accounts[1], BCN.address, { from: accounts[0] })
        var eventLog = res.logs.find(element => element.event.match('ScanRequested'))
        assert.strictEqual(eventLog.args.addressToScan, accounts[1])
        var newBalance = await BCN.balanceOf(accounts[0], { from: accounts[1] });
        assert.strictEqual(newBalance.toNumber(), previousBalance.toNumber() - 1);

        await BSC.addWorker(accounts[2], {from: accounts[0]});
        await BSC.addScoreType("score_1", { from: accounts[0] });
        await BSC.addScoreType("score_2", { from: accounts[0] });
        var results = await BSC.getNextScanJob({ from: accounts[2] });
        var score = "score_1=35;score_2=3443;";
        var res = await BSC.pushScanResult(results[0], score, { from: accounts[2] });
        var eventLog = res.logs.find(element => element.event.match('ScanResultSubmitted'))
        assert.strictEqual(eventLog.args.addressScanned, accounts[1])
        var scoreResults = await BSC.getScanResult(accounts[1], { from: accounts[0]});
        assert.strictEqual(scoreResults[1], score);
    })

    it('scan holding fail: should not allow a scan with unsupported payment methods', async () => {
        await expectThrow(BSC.scanAddressWithHolding(accounts[1], BCN.address, { from: accounts[0] }))
    })

    it('scan holding fail: not enough holding for given payment method', async () => {
        await BSC.addAuthorizedAdmin(accounts[0], { from: accounts[0] });
        // requires 1 blue held
        await BSC.upsertPaymentMethod(BCN.address, "BLUECoin, best payment method", 2, 1, { from: accounts[0] })

        // dont have any
        await expectThrow(BSC.scanAddressWithHolding(accounts[1], BCN.address, { from: accounts[6] }))
    })
    
    it('scan holding success: event emmited', async () => {
        await BSC.addAuthorizedAdmin(accounts[0], { from: accounts[0] });
        // requires 5 blue held
        await BSC.upsertPaymentMethod(BCN.address, "BLUECoin, best payment method", 2, 5, { from: accounts[0] });
        // transfer account 3, 5 blue
        await BCN.transfer(accounts[3], 5, { from: accounts[0] });

        // holding 5
        var res = await BSC.scanAddressWithHolding(accounts[1], BCN.address, { from: accounts[3] });
        var eventLog = res.logs.find(element => element.event.match('ScanRequested'))
        assert.strictEqual(eventLog.args.addressToScan, accounts[1])
    })

    it('scan payment result success: event emmited, result sent', async () => {
        await BSC.addAuthorizedAdmin(accounts[0], { from: accounts[0] });
        // requires 5 blue held
        await BSC.upsertPaymentMethod(BCN.address, "BLUECoin, best payment method", 2, 5, { from: accounts[0] });
        // transfer account 3, 5 blue
        await BCN.transfer(accounts[3], 5, { from: accounts[0] });

        // holding 5
        var res = await BSC.scanAddressWithHolding(accounts[1], BCN.address, { from: accounts[3] });
        var eventLog = res.logs.find(element => element.event.match('ScanRequested'))
        assert.strictEqual(eventLog.args.addressToScan, accounts[1])

        await BSC.addWorker(accounts[2], { from: accounts[0] });
        await BSC.addScoreType("score_1", { from: accounts[0] });
        await BSC.addScoreType("score_2", { from: accounts[0] });
        var results = await BSC.getNextScanJob({ from: accounts[2] });
        var score = "score_1=35;score_2=3443;";
        var res = await BSC.pushScanResult(results[0], score, { from: accounts[2] });
        var eventLog = res.logs.find(element => element.event.match('ScanResultSubmitted'))
        assert.strictEqual(eventLog.args.addressScanned, accounts[1])
        var scoreResults = await BSC.getScanResult(accounts[1], { from: accounts[3] });
        assert.strictEqual(scoreResults[1], score);
    })
});
