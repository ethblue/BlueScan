pragma solidity ^0.4.14;

import "./strings.sol";
import './Ownable.sol';
import './BasicToken.sol';

contract BLUEScan is Ownable {
    using strings for *;
    /**
     * The ScanRequest object, stored within scanRequests key of scanQueue
     * class member.
     */
    struct ScanRequest {
        /**
         * Address that requested the scan.
         */
        address scanRequestorAddress;
        /**
         * Address to scan.
         */
        address scanTargetAddress;
        /**
         * The timestamp the scan result was requested.
         */
        uint256 timestamp;
        /**
         * The index of this scan request within the scanRequests key of 
         * scanQueue class member.
         */
         uint256 scanRequestsIndex;
    }
    /**
     * The event logged when a scan is requested.
     */
    event ScanRequested(address addressToScan);
    /**
     * The ScanQueue class member used to store the array of ScanRequests along
     * with an integer holding the next job to be processed.
     */
    struct ScanQueue {
        ScanRequest[] scanRequests;
        uint256 nextJob;
    }
    /**
     * The array of pending scan requests.
     */
    ScanQueue private scanQueue;
    // ------------------------------------------------------------------------>
    /**
     * The ScanResult object, stored within the scanResults class member.
     */
    struct ScanResult {
        /**
         * The authorized address that submitted the scan result.
         */
        address scanWorkerAddress;
        // -------------------------------------------------------------------->
        /**
         * The timestamp the scan result was initated.
         */
        uint256 timestamp;
        // -------------------------------------------------------------------->
        /**
         * A semicolon delimited set of scores.
         */
        string result;
    }
    /**
     * The event logged when a scan result is submitted.
     */
    event ScanResultSubmitted(address addressScanned);
    /**
     * Mapping containing an array of ScanResults for the each address.
     */
    mapping (address => mapping(
        address => ScanResult
        )
    ) private scanResults;
    // ------------------------------------------------------------------------>
    /**
     * The PaymentMethod object, stored within the paymentMethods class member.
     */
    struct PaymentMethod {
        /**
         * The address of the token being used as the payment method.
         */
        address tokenAddress;
        /**
         * A note associated with this payment method.
         */
        string tokenNote;
        /**
         * The amount required to pay when using the scanAddressWithPayment
         * method.
         */
        uint256 amountRequiredPayment;
        /**
         * The amount required to be within the balance of the caller when using
         * the scanAddressWithHolding methid.
         * method.
         */
        uint256 amountRequiredHeld;
    }
    /**
     * Mapping of supported payment methods or Tokens.
     */
    mapping (address => PaymentMethod) private paymentMethods;     
    /**
     * The event logged when a payment method is added or updated.
     */
    event PaymentMethodUpdated(address paymentMethodAddress);
    /**
     * The event logged when a payment method is removed.
     */
    event PaymentMethodRemoved(address paymentMethodAddress);
    // ------------------------------------------------------------------------>
    /**
     * Mapping of authorized addresses of scan workers.
     */
    mapping( address => bool) private authorizedScanWorkers;
    // ------------------------------------------------------------------------>
    /**
     * Mapping of authorized addresses of admins.
     */
    mapping( address => bool) private authorizedAdmins;
    // ------------------------------------------------------------------------>
    /**
     * Mapping of validate score types.
     */
    mapping( string => bool) private validScoreTypes;
    /**
     * The event logged when a score type is added.
     */
    event ScoreTypeAdded(string scoreType);
    /**
     * The event logged when a score type is removed.
     */
    event ScoreTypeRemoved(string scoreType);
    // ------------------------------------------------------------------------>
    /**
     * The constructor of the BLUEScan object.
     */
    function BLUEScan() {
    }
    // ------------------------------------------------------------------------>
    /**
     * Requests a scan of the given address using the given payment method 
     * address. The given payment method address must be a whitelisted payment
     * method and the sender must have approved this contract to spend the amount
     * required to pay for a scan.
     *
     * @param addressToScan The address you would like to scan
     * @param paymentMethodAddress The address of the payment method you will
     *        be using.
     */
    function scanAddressWithPayment (address addressToScan, address paymentMethodAddress) external {
        require(paymentMethods[paymentMethodAddress].amountRequiredPayment > 0);
        require(addressToScan != address(0));

        // TODO: audit for re-entrancy, possibly check for balance before and after
        require(paymentMethodAddress.call(bytes4(keccak256("transferFrom(address,address,uint256)")), msg.sender, address(this), paymentMethods[paymentMethodAddress].amountRequiredPayment));


        uint256 length = scanQueue.scanRequests.length;
        scanQueue.scanRequests.push(ScanRequest(msg.sender,addressToScan,now,length));
        ScanRequested(addressToScan);
    }
    // ------------------------------------------------------------------------>
    /**
     * Requests a scan of the given address using the given payment method 
     * address. The given payment method address must be a whitelisted payment
     * method and the sender must have a balance greater than the amount required
     * to be held.
     *
     * @param addressToScan The address you would like to scan
     * @param paymentMethodAddress The address of the payment method you will
     *        be using.
     */
    function scanAddressWithHolding (address addressToScan, address paymentMethodAddress) external {
        require(paymentMethods[paymentMethodAddress].amountRequiredHeld > 0);
        require(addressToScan != address(0));

        BasicToken token = BasicToken(paymentMethodAddress);
        require(token.balanceOf(msg.sender) >= paymentMethods[paymentMethodAddress].amountRequiredHeld);

        uint256 length = scanQueue.scanRequests.length;
        scanQueue.scanRequests.push(ScanRequest(msg.sender,addressToScan,now,length));
        ScanRequested(addressToScan);
    }
    // ------------------------------------------------------------------------>
    /**
     * Upserts the given payment method info within the paymentMethods class 
     * member.
     *
     * @param tokenAddress
     * @param tokenNote
     * @param amountRequiredPayment
     * @param amountRequiredHeld
     */
    function upsertPaymentMethod (address tokenAddress, string tokenNote, uint256 amountRequiredPayment, uint256 amountRequiredHeld) external onlyAdmin {
        paymentMethods[tokenAddress] = PaymentMethod(tokenAddress, tokenNote, amountRequiredPayment, amountRequiredHeld);
        PaymentMethodUpdated(tokenAddress);
    }
    /**
     * Removes the given payment method info within the paymentMethods class 
     * member.
     *
     * @param tokenAddress
     * @param tokenNote
     * @param amountRequiredPayment
     * @param amountRequiredHeld
     */
    function removePaymentMethod (address tokenAddress) external onlyAdmin {
        require(paymentMethods[tokenAddress].tokenAddress != address(0));
        delete paymentMethods[tokenAddress];
        PaymentMethodRemoved(tokenAddress);
    }
    // ------------------------------------------------------------------------>
    /**
     * Adds the given scoreType string to the validscoreTypes class member.
     *
     * @param scoreType a string identifying the score type
     */
    function addScoreType (string scoreType) external onlyAdmin {
        validScoreTypes[scoreType] = true;
        ScoreTypeAdded(scoreType);
    }
    /**
     * Removes the given scoreType string from the validscoreTypes class member.
     *
     * @param scoreType a string identifying the score type
     */
    function removeScoreType (string scoreType) external onlyAdmin {
        delete validScoreTypes[scoreType];
        ScoreTypeRemoved(scoreType);
    }
    // ------------------------------------------------------------------------>
    /**
     * Adds the given address to the authorizedScanWorkers class member.
     *
     * @param workerAddress
     */
    function addWorker (address workerAddress) external onlyAdmin {
        authorizedScanWorkers[workerAddress] = true;
    }
    /**
     * Removes the given address to the authorizedScanWorkers class member.
     *
     * @param workerAddress
     */
    function removeWorker (address workerAddress) external onlyAdmin {
        delete authorizedScanWorkers[workerAddress];
    }
    // ------------------------------------------------------------------------>
    function addAuthorizedAdmin (address adminAddress) external onlyOwner {
        authorizedAdmins[adminAddress] = true;
    }
    function removeAuthorizedAdmin (address adminAddress) external onlyOwner {
        delete authorizedAdmins[adminAddress];
    }
    // ------------------------------------------------------------------------>
    function getNextScanJob() constant external onlyWorker  returns (uint256, address, address, uint256, uint256) {
        ScanRequest memory nextScanJob = scanQueue.scanRequests[scanQueue.nextJob];
        require(nextScanJob.timestamp != 0);
        return (
            scanQueue.nextJob,
            nextScanJob.scanRequestorAddress,
            nextScanJob.scanTargetAddress,
            nextScanJob.timestamp,
            nextScanJob.scanRequestsIndex
        );
    }
    function pushScanResult (uint256 scanJobIndex, string scanResultsKvp) external onlyWorker {
        require(scanQueue.scanRequests[scanJobIndex].timestamp != 0);

        // grab the information needed from the ScanRequest object
        address addressScanned = scanQueue.scanRequests[scanJobIndex].scanTargetAddress;
        address addressScanRequestor = scanQueue.scanRequests[scanJobIndex].scanRequestorAddress;
       
        // we have to build the mapping by exploding the scanResultKVP
        // Example score_1=5;score_2=6;
        strings.slice memory delimiter = ";".toSlice();
        strings.slice memory delimiterEquals = "=".toSlice();
        strings.slice memory scanResultsKvpSlice = scanResultsKvp.toSlice();
        uint256 numberOfScores = scanResultsKvpSlice.count(delimiter);

        strings.slice memory score;
        string memory scoreKey;
        for (uint256 i = 0; i < numberOfScores; i++) {
            score = scanResultsKvpSlice.split(delimiter);
            scoreKey = score.split(delimiterEquals).toString();
            require(validScoreTypes[scoreKey] == true);
        }
        
        scanResults[addressScanRequestor][addressScanned] = ScanResult(msg.sender, now, scanResultsKvp);
        ScanResultSubmitted(addressScanned);
        delete scanQueue.scanRequests[scanJobIndex];

        scanQueue.nextJob++;
    }
    function getScanResult(address addressScanned) constant external returns (uint256, string) {
        require(scanResults[msg.sender][addressScanned].timestamp != 0);
        return (
            scanResults[msg.sender][addressScanned].timestamp,
            scanResults[msg.sender][addressScanned].result
        );
    }
    // ------------------------------------------------------------------------>
    modifier onlyWorker() {
        require(authorizedScanWorkers[msg.sender] == true);
        _;
    }
    // ------------------------------------------------------------------------>
    modifier onlyAdmin() {
        require(authorizedAdmins[msg.sender] == true);
        _;
    }
}