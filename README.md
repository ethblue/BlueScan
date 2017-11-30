# BlueScan
This repo contains a Solidity smart contract that allows for scan requests to be made using multiple
different payment models.
Once a scan request is made, a registered worker can retrieve the scan request job, process the request, and submit his results.
All results are stored within the smart contract itself.

### Administration
Administrators can only be managed by the owner. 
Their addresses are managed using the addAuthorizedAdmin and removeAuthorizedAdmin methods.
Administrators are responsible for the following.

1. Management of the available payment methods (tokens) and their exchange / holding rates.
2. Management of the available scan workers.
3. Management of the available score types within a scan result.

### Workers
Workers can only be managed by administrators.
Their addresses are managed using the addWorker and removeWorker methods.
Works are responsible for the following.

1. Listening for the ScanResultSubmitted events and retrieve jobs.
2. Proccessing of said job and submitting the results.


## Testing
To run the test suite for the BlueScan contract, run the following.
```
npm install
truffle develop
test
```

## TODO
1. Audit gas usage.
2. Audit visiblity modifiers.
3. Audit general security vulnerabilities.
4. Add support for ether payments.
5. Use saferMath library
6. Test on non local network
7. Finish method documentation
8. Add way to retrieve results
9. modifier to check a blacklist of addresses
10. Test holdings workflow