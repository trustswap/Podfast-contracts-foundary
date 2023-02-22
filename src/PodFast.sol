// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;
import "openzeppelin-contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "openzeppelin-contracts-upgradeable/access/OwnableUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";

contract PodFast is Initializable, IERC20Upgradeable, OwnableUpgradeable {
    using SafeMathUpgradeable for uint256;

    address zero;

    uint32 public maxTaxFee;
    uint32 public maxWalletFee;
    uint32 public maxEcosystemFee;

    mapping(address => uint256) private _rOwned;
    mapping(address => uint256) private _tOwned;
    mapping(address => mapping(address => uint256)) private _allowances;

    mapping(address => bool) private _isExcludedFromFee;

    mapping(address => bool) private _isExcluded;
    address[] private _excluded;

    uint256 public _tTotal;
    uint256 private _rTotal;
    uint256 private _tFeeTotal;

    string public _name;
    string public _symbol;
    uint8 private _decimals;

    uint32 public _taxFee; // Fee for Reflection
    uint32 private _previousTaxFee;

    uint32 public _walletFee; // Fee to owner
    uint32 private _previousWalletFee;

    uint32 public _ecoSystemFee; // fee for ecosystem
    uint32 private _previousEcoSystemFee;

    address payable public feeWallet; // owner fee wallet
    address payable public ecoSystemWallet; // ecosystem fee wallet
    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        string memory __name,
        string memory __symbol,
        uint8 __decimals,
        uint32 _tax_reflection,
        uint32 _tax_wallet,
        uint32 _tax_ecosystem,
        uint256 _initial,
        address _feeWallet,
        address _ecoSystemWallet
    ) initializer public {

        __Ownable_init();

        uint256 MAX = ~uint256(0);
        maxTaxFee = 1000;
        maxWalletFee = 1000;
        maxEcosystemFee = 1000;
        zero = address(0); 

        _name = __name;
        _symbol = __symbol;
        _decimals = __decimals;
        _tTotal = _initial;
        _rTotal = (MAX - (MAX % _tTotal));

        _rOwned[_msgSender()] = _rTotal;

        feeWallet = payable(_feeWallet);
        ecoSystemWallet = payable(_ecoSystemWallet);

        _isExcludedFromFee[_msgSender()] = true;
        // _isExcludedFromFee[_feeWallet] = true;
        // _isExcludedFromFee[address(this)] = true;         
        // _isExcludedFromFee[_ecoSystemWallet] = true;

        excludeFromReward(_msgSender());
        // excludeFromReward(_feeWallet);
        // excludeFromReward(address(this));
        // excludeFromReward(_ecoSystemWallet);

        _taxFee = _tax_reflection;
        _walletFee = _tax_wallet;
        _ecoSystemFee = _tax_ecosystem;

        emit Transfer(address(0), _msgSender(), _tTotal);
    }

    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function decimals() public view returns (uint8) {
        return _decimals;
    }

    function totalSupply() public view override returns (uint256) {
        return _tTotal;
    }

    function balanceOf(address account) public view override returns (uint256) {
        if (_isExcluded[account]) return _tOwned[account];
        return tokenFromReflection(_rOwned[account]);
    }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(
            sender,
            _msgSender(),
            _allowances[sender][_msgSender()].sub(amount, "PodFast: transfer amount exceeds allowance")
        );
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].add(addedValue));
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        _approve(
            _msgSender(),
            spender,
            _allowances[_msgSender()][spender].sub(subtractedValue, "PodFast: Cannot decrease allowance below zero")
        );
        return true;
    }

    function isExcludedFromReward(address account) public view returns (bool) {
        return _isExcluded[account];
    }

    function totalFees() public view returns (uint256) {
        return _tFeeTotal;
    }

    function deliver(uint256 tAmount) public {
        address sender = _msgSender();
        require(!_isExcluded[sender], "PodFast: Excluded addresses cannot call this function");
        (uint256 rAmount, , , , , ,) = _getValues(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _rTotal = _rTotal.sub(rAmount);
        _tFeeTotal = _tFeeTotal.add(tAmount);
    }

    function reflectionFromToken(uint256 tAmount, bool deductTransferFee) public view returns (uint256) {
        require(tAmount <= _tTotal, "PodFast: Amount must be less than the Total Supply");
        if (!deductTransferFee) {
            (uint256 rAmount, , , , , ,) = _getValues(tAmount);
            return rAmount;
        } else {
            (, uint256 rTransferAmount, , , , ,) = _getValues(tAmount);
            return rTransferAmount;
        }
    }

    function tokenFromReflection(uint256 rAmount) public view returns (uint256) {
        require(rAmount <= _rTotal, "PodFast: Amount must be less than total reflections");
        uint256 currentRate = _getRate();
        return rAmount.div(currentRate);
    }

    function excludeFromReward(address account) public onlyOwner {
        if (!_isExcluded[account]) {
            if (_rOwned[account] > 0) {
                _tOwned[account] = tokenFromReflection(_rOwned[account]);
            }
            _isExcluded[account] = true;
            _excluded.push(account);
        }
    }

    function includeInReward(address account) external onlyOwner {
        require(_isExcluded[account], "PodFast: Already included");
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (_excluded[i] == account) {
                _excluded[i] = _excluded[_excluded.length - 1];
                _tOwned[account] = 0;
                _isExcluded[account] = false;
                _excluded.pop();
                break;
            }
        }
    }

    function excludeFromFee(address account) public onlyOwner {
        _isExcludedFromFee[account] = true;
    }

    function includeInFee(address account) public onlyOwner {
        _isExcludedFromFee[account] = false;
    }

    function setAllFeePercent(
        uint32 taxFee,
        uint32 walletFee,
        uint32 ecosystemFee
    ) external onlyOwner {
        require(taxFee >= 0 && taxFee <= maxTaxFee, "PodFast: TaxFee over limit");
        require(walletFee >= 0 && walletFee <= maxWalletFee, "PodFast: WalletFee over limit");
        require(ecosystemFee >= 0 && ecosystemFee <= maxEcosystemFee, "PodFast: EcosystemFee over limit");
        _taxFee = taxFee;
        _walletFee = walletFee;
        _ecoSystemFee = ecosystemFee;
    }

    function setFeeWallet(address payable newFeeWallet) external onlyOwner {
        require(newFeeWallet != address(0), "PodFast: Can't set ZERO Address");
        excludeFromReward(newFeeWallet);
        feeWallet = newFeeWallet;
    }

    function setEcosystemWallet(address payable newEcosystemWallet) external onlyOwner {
        require(newEcosystemWallet != address(0), "PodFast: Can't set ZERO Address");
        excludeFromReward(newEcosystemWallet);
        ecoSystemWallet = newEcosystemWallet;
    }

    receive() external payable {}

    function _reflectFee(uint256 rFee, uint256 tFee) private {
        _rTotal = _rTotal.sub(rFee);
        _tFeeTotal = _tFeeTotal.add(tFee);
    }

    function _getValues(uint256 tAmount)
        private
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        (uint256 tTransferAmount, uint256 tFee, uint256 tOwnerFee, uint256 tEcosystem) = _getTValues(tAmount);
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee) = _getRValues(tAmount, tFee, tOwnerFee, tEcosystem,_getRate());
        return (rAmount, rTransferAmount, rFee, tTransferAmount, tFee, tOwnerFee, tEcosystem);
    }

    function _getTValues(uint256 tAmount)
        private
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        uint256 tFee = calculateTaxFee(tAmount);
        uint256 tOwnerFee = calculateOwnerFee(tAmount);
        uint256 tEcosystem = calculateEcosystemFee(tAmount);
        uint256 tTransferAmount = tAmount.sub(tFee).sub(tOwnerFee).sub(tEcosystem);
        return (tTransferAmount, tFee, tOwnerFee, tEcosystem);
    }

    function _getRValues(
        uint256 tAmount,
        uint256 tFee,
        uint256 tOwnerFee,
        uint256 tEcosystem,
        uint256 currentRate
    )
        private
        pure
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        uint256 rAmount = tAmount.mul(currentRate);
        uint256 rFee = tFee.mul(currentRate);
        uint256 rOwnerFee = tOwnerFee.mul(currentRate);
        uint256 rEcosystem = tEcosystem.mul(currentRate);
        uint256 rTransferAmount = rAmount.sub(rFee).sub(rOwnerFee).sub(rEcosystem);
        return (rAmount, rTransferAmount, rFee);
    }

    function _getRate() public view returns (uint256) {
        (uint256 rSupply, uint256 tSupply) = _getCurrentSupply();
        return rSupply.div(tSupply);
    }

    function _getCurrentSupply() private view returns (uint256, uint256) {
        uint256 rSupply = _rTotal;
        uint256 tSupply = _tTotal;
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (_rOwned[_excluded[i]] > rSupply || _tOwned[_excluded[i]] > tSupply) return (_rTotal, _tTotal);
            rSupply = rSupply.sub(_rOwned[_excluded[i]]);
            tSupply = tSupply.sub(_tOwned[_excluded[i]]);
        }
        if (rSupply < _rTotal.div(_tTotal)) return (_rTotal, _tTotal);
        return (rSupply, tSupply);
    }

    function _takeOwnerFee(uint256 tOwnerFee) private {
        uint256 currentRate = _getRate();
        uint256 rOwnerFee = tOwnerFee.mul(currentRate);
        _rOwned[feeWallet] = _rOwned[feeWallet].add(rOwnerFee);
        if (_isExcluded[feeWallet]) _tOwned[feeWallet] = _tOwned[feeWallet].add(tOwnerFee);
    }

    function _takeEcosystemFee(uint256 tEcosystem) private {
        uint256 currentRate = _getRate();
        uint256 rEcosystem = tEcosystem.mul(currentRate);
        _rOwned[ecoSystemWallet] = _rOwned[ecoSystemWallet].add(rEcosystem);
        if (_isExcluded[ecoSystemWallet]) _tOwned[ecoSystemWallet] = _tOwned[ecoSystemWallet].add(tEcosystem);
    }

    function calculateTaxFee(uint256 _amount) private view returns (uint256) {
        return _amount.mul(_taxFee).div(10**4);
    }

    function calculateEcosystemFee (uint256 _amount) private view returns (uint256) {
        return _amount.mul(_ecoSystemFee).div(10**4);
    }

    function calculateOwnerFee(uint256 _amount) private view returns (uint256) {
        return _amount.mul(_walletFee).div(10**4);
    }

    function removeAllFee() private {
        if (_taxFee == 0 && _walletFee == 0 && _ecoSystemFee == 0) return;

        _previousTaxFee = _taxFee;
        _previousWalletFee = _walletFee;
        _previousEcoSystemFee = _ecoSystemFee;

        _taxFee = 0;
        _walletFee = 0;
        _ecoSystemFee = 0;
    }

    function restoreAllFee() private {
        _taxFee = _previousTaxFee;
        _walletFee = _previousWalletFee;
        _ecoSystemFee = _previousEcoSystemFee;
    }

    function isExcludedFromFee(address account) public view returns (bool) {
        return _isExcludedFromFee[account];
    }

    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) private {
        require(owner != address(0), "PodFast: cannot approve from zero address");
        require(spender != address(0), "PodFast: cannot approve to zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) private {
        require(from != address(0), "PodFast: transfer from zero address");
        require(to != address(0), "PodFast: transfer to zero address");
        require(amount > 0, "PodFast: Transfer amount must be greater than zero");

        //indicates if fee should be deducted from transfer
        bool takeFee = true;

        //if any account belongs to _isExcludedFromFee account then remove the fee
        if (_isExcludedFromFee[from] || _isExcludedFromFee[to]) {
            takeFee = false;
        }

        //transfer amount, it will take tax, ecosystem, owner fee
        _tokenTransfer(from, to, amount, takeFee);
    }

    //this method is responsible for taking all fee, if takeFee is true
    function _tokenTransfer(
        address sender,
        address recipient,
        uint256 amount,
        bool takeFee
    ) private {
        if (!takeFee) removeAllFee();

        if (_isExcluded[sender] && !_isExcluded[recipient]) {
            _transferFromExcluded(sender, recipient, amount);
        } else if (!_isExcluded[sender] && _isExcluded[recipient]) {
            _transferToExcluded(sender, recipient, amount);
        } else if (!_isExcluded[sender] && !_isExcluded[recipient]) {
            _transferStandard(sender, recipient, amount);
        } else if (_isExcluded[sender] && _isExcluded[recipient]) {
            _transferBothExcluded(sender, recipient, amount);
        } else {
            _transferStandard(sender, recipient, amount);
        }
        if (!takeFee) restoreAllFee();
    }

    function _transferStandard(
        address sender,
        address recipient,
        uint256 tAmount
    ) private {
        (
            uint256 rAmount,
            uint256 rTransferAmount,
            uint256 rFee,
            uint256 tTransferAmount,
            uint256 tFee,
            uint256 tOwnerFee,
            uint256 tEcosystem

        ) = _getValues(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
        _takeOwnerFee(tOwnerFee);
        _takeEcosystemFee(tEcosystem);
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _transferToExcluded(
        address sender,
        address recipient,
        uint256 tAmount
    ) private {
        (
            uint256 rAmount,
            uint256 rTransferAmount,
            uint256 rFee,
            uint256 tTransferAmount,
            uint256 tFee,
            uint256 tOwnerFee,
            uint256 tEcosystem
        ) = _getValues(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _tOwned[recipient] = _tOwned[recipient].add(tTransferAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
        _takeOwnerFee(tOwnerFee);
        _takeEcosystemFee(tEcosystem);
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _transferFromExcluded(
        address sender,
        address recipient,
        uint256 tAmount
    ) private {
        (
            uint256 rAmount,
            uint256 rTransferAmount,
            uint256 rFee,
            uint256 tTransferAmount,
            uint256 tFee,
            uint256 tOwnerFee,
            uint256 tEcosystem
        ) = _getValues(tAmount);
        _tOwned[sender] = _tOwned[sender].sub(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
        _takeOwnerFee(tOwnerFee);
        _takeEcosystemFee(tEcosystem);
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _transferBothExcluded(
        address sender,
        address recipient,
        uint256 tAmount
    ) private {
        (
            uint256 rAmount,
            uint256 rTransferAmount,
            uint256 rFee,
            uint256 tTransferAmount,
            uint256 tFee,
            uint256 tOwnerFee,
            uint256 tEcosystem
        ) = _getValues(tAmount);
        _tOwned[sender] = _tOwned[sender].sub(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _tOwned[recipient] = _tOwned[recipient].add(tTransferAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
        _takeOwnerFee(tOwnerFee);
        _takeEcosystemFee(tEcosystem);
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }
}