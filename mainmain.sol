pragma solidity ^0.8.0;

contract MultiSigWallet {
    address[] public owners;
    mapping(address => bool) public isOwner;
    uint public numConfirmationsRequired;
    mapping (address => uint) public balances;

    struct Transaction {
        address to;
        uint value;
        bool executed;
        mapping (address => bool) isConfirmed;
        uint numConfirmations;
    }

    Transaction[] public transactions;

    event Deposit(address indexed sender, uint amount);
    event SubmitTransaction(address indexed owner, uint indexed txIndex, address indexed to, uint value);
    event ConfirmTransaction(address indexed owner, uint indexed txIndex);
    event ExecuteTransaction(address indexed owner, uint indexed txIndex);
    event RevokeConfirmation(address indexed owner, uint indexed txIndex);

    constructor(address[] memory _owners, uint _numConfirmationsRequired) {
        require(_owners.length > 0, "Owners are required");
        require(_numConfirmationsRequired > 0 && _numConfirmationsRequired <= _owners.length, "Invalid number of required confirmations");

        for (uint i = 0; i < _owners.length; i++) {
            address owner = _owners[i];

            require(owner != address(0), "Invalid owner");
            require(!isOwner[owner], "Owner not unique");

            isOwner[owner] = true;
            owners.push(owner);
        }

        numConfirmationsRequired = _numConfirmationsRequired;
    }

    receive() external payable {
        emit Deposit(msg.sender, msg.value);
    }

    function submitTransaction(address _to, uint _value) public onlyOwners {
        uint txIndex = transactions.length;

        transactions.push(Transaction({
            to: _to,
            value: _value,
            executed: false,
            numConfirmations: 0
        }));

        emit SubmitTransaction(msg.sender, txIndex, _to, _value);
    }

    function confirmTransaction(uint _txIndex) public onlyOwners transactionExists(_txIndex) notConfirmed(_txIndex, msg.sender) {
        Transaction storage transaction = transactions[_txIndex];
        transaction.isConfirmed[msg.sender] = true;
        transaction.numConfirmations++;

        emit ConfirmTransaction(msg.sender, _txIndex);
    }

    function executeTransaction(uint _txIndex) public onlyOwners transactionExists(_txIndex) notExecuted(_txIndex) hasEnoughConfirmations(_txIndex) {
        Transaction storage transaction = transactions[_txIndex];
        transaction.executed = true;

        (bool success, ) = transaction.to.call{value: transaction.value}("");
        require(success, "Transaction failed");

        emit ExecuteTransaction(msg.sender, _txIndex);
    }

    function revokeConfirmation(uint _txIndex) public onlyOwners transactionExists(_txIndex) confirmed(_txIndex, msg.sender) notExecuted(_txIndex) {
        Transaction storage transaction = transactions[_txIndex];
        transaction.isConfirmed[msg.sender] = false;
        transaction.numConfirmations--;

        emit RevokeConfirmation(msg.sender, _txIndex);
    }

    modifier onlyOwners() {
        require(isOwner[msg.sender], "Not an owner");
        _;
    }

    modifier transactionExists(uint _txIndex) {
        require(_txIndex < transactions.length, "Transaction does not exist");
        _;
    }

    modifier notExecuted(uint _txIndex) {
        require(!transactions[_txIndex].executed, "Transaction already executed");
        _;
    }

    modifier notConfirmed(uint _txIndex, address _owner) {
        require(!transactions[_txIndex].isConfirmed[_owner], "Transaction already confirmed");
        _;
    }

    modifier confirmed(uint _txIndex, address _owner) {
        require(transactions[_txIndex].isConfirmed[_owner], "Transaction not confirmed");
        _;
    }

    modifier hasEnoughConfirmations(uint _txIndex) {
        require(transactions[_txIndex].numConfirmations >= numConfirmationsRequired, "Not enough confirmations");
        _;
    }
}


