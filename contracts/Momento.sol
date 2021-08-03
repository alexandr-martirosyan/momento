// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./interfaces/IUniswapV2Router02.sol";
import "./interfaces/IUniswapV2Factory.sol";

import "hardhat/console.sol";

contract Momento is IERC20, Ownable {
    struct User {
        uint256 buy;
        uint256 sell;
    }

    address public marketingAddress = payable(0xCfc5835d709A837d7445C0a881c293fF58309d5a);
    address public teamAddress = payable(0x857ed7E7b4C40F29CB7391FCF88EAc76BD284032);
    address public constant stakingAddress = payable(0xad11F3c07aa816e36de174eB53F6603FB62eDA18);
    address public constant deadAddress = 0x000000000000000000000000000000000000dEaD;

    uint256 private _rTeamLock;

    uint256 public teamUnlockTime;
    uint8 public teamUnlockCount;
    uint256 private _rTeamUnlockTokenCount;

    uint256 private _rBurnLock;
    uint256 private _tBurnLock;

    mapping(address => User) private _cooldown;

    mapping (address => uint256) private _rOwned;
    mapping (address => uint256) private _tOwned;
    mapping (address => mapping (address => uint256)) private _allowances;

    mapping (address => bool) private _isExcludedFromFee;

    mapping (address => bool) private _isExcluded;
    address[] private _excluded;

    uint256 private _holderCount;
    uint256 private _lastMaxHolderCount = 99;
   
    uint256 private constant MAX = ~uint256(0);
    uint256 private _tTotal = 1000000000000 * 10**9;
    uint256 private _rTotal = (MAX - (MAX % _tTotal));
    uint256 private _tFeeTotal;

    string private _name = "Momento";
    string private _symbol = "MOMENTO";
    uint8 private _decimals = 9;
    
    uint256 public _taxFee = 5;
    uint256 private _previousTaxFee = _taxFee;
    
    uint256 public _liquidityFee = 5;
    uint256 private _previousLiquidityFee = _liquidityFee;

    uint256 public _marketingFee = 1;
    uint256 private _previousMarketingFee = _marketingFee;
    
    uint256 public _buyBackFee = 4;
    uint256 private _previousBuyBackFee = _buyBackFee;

    IUniswapV2Router02 public immutable uniswapV2Router;
    address public immutable uniswapV2Pair;
    
    bool inSwapAndLiquify;
    bool public swapAndLiquifyEnabled = true;
    
    uint256 public _maxTxAmount = 5000000000 * 10**9;
    uint256 private numTokensSellToAddToLiquidity = 500000000 * 10**9;
    
    event MinTokensBeforeSwapUpdated(uint256 minTokensBeforeSwap);
    event SwapAndLiquifyEnabledUpdated(bool enabled);
    event SwapAndLiquify(uint256 tokensSwapped, uint256 ethReceived, uint256 tokensIntoLiqudity);
    event SwapETHForTokens(uint256 amountIn, address[] path);
    
    modifier lockTheSwap {
        inSwapAndLiquify = true;
        _;
        inSwapAndLiquify = false;
    }
    
    constructor() {
        // 1% of total reflection supply
        uint256 onePercentR = _rTotal / 100;
        // 1% of total t supply
        uint256 onePercentT = _tTotal / 100;

        // add 60% of tokens to owner(for adding to liquidity pool)
        _rOwned[_msgSender()] = onePercentR * 60;
        // add 5% of tokens to marketing address
        _rOwned[marketingAddress] = onePercentR * 5;
        // add 12% of tokens to staking address
        _rOwned[stakingAddress] = onePercentR * 12;
        // lock 10% of tokens for burning further
        _rBurnLock = onePercentR * 10;
        _tBurnLock = onePercentT * 10;
        // lock 3% of tokens for team for 6 months and vested over 18 months
        _rTeamLock = onePercentR * 3;

        _rTeamUnlockTokenCount = _rTeamLock / 18;

        teamUnlockTime = block.timestamp + 180 days;

        // burning 10% of totalsupply
        _rTotal = onePercentR * 90;
        _tTotal = onePercentT * 90;


        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
        // Create a uniswap pair for this new token
        uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory()).createPair(address(this), _uniswapV2Router.WETH());

        // set the rest of the contract variables
        uniswapV2Router = _uniswapV2Router;
        
        // exclude owner and this contract from fee
        _isExcludedFromFee[owner()] = true;
        _isExcludedFromFee[address(this)] = true;

        console.log("Max is     ->", MAX);
        console.log("R total is ->", _rTotal);
        console.log("T total is ->", _tTotal);
        
        emit Transfer(address(0), _msgSender(), onePercentT * 60);
        emit Transfer(address(0), marketingAddress, onePercentT * 5);
        emit Transfer(address(0), stakingAddress, onePercentT * 12);
        emit Transfer(deadAddress, address(0), onePercentT * 10);
    }

    function unlockTeam() public {
        require(_msgSender() == teamAddress, "Function can be called only with team address");
        require(block.timestamp > teamUnlockTime, "Fucntion can be called only if teamUnlockTime has passed");
        require(teamUnlockCount < 18, "You are already unlocked all tokens");
        uint256 difference = block.timestamp - teamUnlockTime;
        uint256 monthCount = difference / 30 days;
        uint8 remainingMonths = 18 - teamUnlockCount;
        if (monthCount > remainingMonths) monthCount = remainingMonths;
        uint amountToTransfer = monthCount * _rTeamUnlockTokenCount;
        _rOwned[teamAddress] += amountToTransfer;
        teamUnlockCount += uint8(monthCount);
        teamUnlockTime += monthCount * 30 days;
        emit Transfer(address(0), teamAddress, tokenFromReflection(amountToTransfer));
    }

    function setMarketingAddress(address _markeingAddress) public onlyOwner {
        marketingAddress = _markeingAddress;
    }

    function setTeamAddress(address _teamAddress) public onlyOwner {
        teamAddress = _teamAddress;
    }

    function _burnTenPercent() private {
        if (_tBurnLock != 0) {
            uint256 tBurnCount = _tBurnLock / 10;
            uint256 rBurnCount = _rBurnLock / 10;
            if (tBurnCount == 0) {
                tBurnCount = _tBurnLock;
                rBurnCount = _rBurnLock;
            }
            _tBurnLock -= tBurnCount;
            _rBurnLock -= rBurnCount;
            _tTotal -= tBurnCount;
            _rTotal -= rBurnCount;
            emit Transfer(deadAddress, address(0), tBurnCount);
        }
    }

    function name() public view returns (string memory) {
        console.log('Calling name function');
        return _name;
    }

    function symbol() public view returns (string memory) {
        console.log('Calling symbol function');
        return _symbol;
    }

    function decimals() public view returns (uint8) {
        console.log('Calling decimals function');
        return _decimals;
    }

    function totalSupply() public view override returns (uint256) {
        console.log('Calling totalSupply function');
        return _tTotal;
    }

    function balanceOf(address account) public view override returns (uint256) {
        console.log('Calling balanceOf function');
        if (_isExcluded[account]) return _tOwned[account];
        return tokenFromReflection(_rOwned[account]);
    }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        console.log('Calling transfer function');
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) public view override returns (uint256) {
        console.log('Calling allowance function');
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        console.log('Calling approve function');
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        console.log('Calling transferFrom function');
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()] - amount);
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        console.log('Calling increaseAllowance function');
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender] + addedValue);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        console.log('Calling decreaseAllowance function');
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender] - subtractedValue);
        return true;
    }

    function isExcludedFromReward(address account) public view returns (bool) {
        console.log('Calling isExcludedFromReward function');
        return _isExcluded[account];
    }

    function totalFees() public view returns (uint256) {
        console.log('Calling totalFees function');
        return _tFeeTotal;
    }

    function deliver(uint256 tAmount) public {
        console.log('Calling deliver function');
        address sender = _msgSender();
        require(!_isExcluded[sender], "Excluded addresses cannot call this function");
        (uint256 rAmount,,,,,,,) = _getValues(tAmount);
        _rOwned[sender] = _rOwned[sender] - rAmount;
        _rTotal = _rTotal - rAmount;
        _tFeeTotal = _tFeeTotal + tAmount;
    }

    function reflectionFromToken(uint256 tAmount, bool deductTransferFee) public view returns(uint256) {
        console.log('Calling reflectionFromToken function');
        require(tAmount <= _tTotal, "Amount must be less than supply");
        if (!deductTransferFee) {
            (uint256 rAmount,,,,,,,) = _getValues(tAmount);
            return rAmount;
        } else {
            (,uint256 rTransferAmount,,,,,,) = _getValues(tAmount);
            return rTransferAmount;
        }
    }

    function tokenFromReflection(uint256 rAmount) public view returns(uint256) {
        console.log('Calling tokenFromReflection function');
        require(rAmount <= _rTotal, "Amount must be less than total reflections");
        uint256 currentRate = _getRate();
        return rAmount / currentRate;
    }

    function excludeFromReward(address account) public onlyOwner() {
        console.log('Calling excludeFromReward function');
        // require(account != 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D, 'We can not exclude Uniswap router.');
        require(!_isExcluded[account], "Account is already excluded");
        if(_rOwned[account] > 0) {
            _tOwned[account] = tokenFromReflection(_rOwned[account]);
        }
        _isExcluded[account] = true;
        _excluded.push(account);
    }

    function includeInReward(address account) external onlyOwner() {
        console.log('Calling includeInReward function');
        require(_isExcluded[account], "Account is already excluded");
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

    function _transferBothExcluded(address sender, address recipient, uint256 tAmount) private {
        console.log('Calling _transferBothExcluded function');
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 rMarketing, uint256 tTransferAmount, uint256 tFee, uint256 tLiquidity, uint256 tBuyBack) = _getValues(tAmount);
        _tOwned[sender] -= tAmount;
        _rOwned[sender] -= rAmount;
        _tOwned[recipient] += tTransferAmount;
        _rOwned[recipient] += rTransferAmount;        
        _rOwned[marketingAddress] += rMarketing;
        _tOwned[deadAddress] += tBuyBack;
        _takeLiquidity(tLiquidity);
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }
    
    function excludeFromFee(address account) public onlyOwner {
        console.log('Calling excludeFromFee function');
        _isExcludedFromFee[account] = true;
    }
    
    function includeInFee(address account) public onlyOwner {
        console.log('Calling includeInFee function');
        _isExcludedFromFee[account] = false;
    }
    
    function setTaxFeePercent(uint256 taxFee) external onlyOwner() {
        console.log('Calling setTaxFeePercent function');
        _taxFee = taxFee;
    }
    
    function setLiquidityFeePercent(uint256 liquidityFee) external onlyOwner() {
        console.log('Calling setLiquidityFeePercent function');
        _liquidityFee = liquidityFee;
    }
   
    function setMaxTxPercent(uint256 maxTxPercent) external onlyOwner() {
        console.log('Calling setMaxTxPercent function');
        _maxTxAmount = _tTotal * maxTxPercent / 100;
    }

    function setSwapAndLiquifyEnabled(bool _enabled) public onlyOwner {
        console.log('Calling setSwapAndLiquifyEnabled function');
        swapAndLiquifyEnabled = _enabled;
        emit SwapAndLiquifyEnabledUpdated(_enabled);
    }
    
    //to recieve ETH from uniswapV2Router when swaping
    receive() external payable {
        console.log('Calling receive function with %d Wei', msg.value);
    }

    function _reflectFee(uint256 rFee, uint256 tFee) private {
        console.log('Calling _reflectFee function');
        _rTotal = _rTotal - rFee;
        _tFeeTotal = _tFeeTotal + tFee;
    }

    function _getValues(uint256 tAmount) private view returns (uint256, uint256, uint256, uint256, uint256, uint256, uint256, uint256) {
        console.log('Calling _getValues function');
        uint256[5] memory tValues = _getTValues(tAmount);
        uint256[4] memory rValues = _getRValues(tAmount, tValues[0], tValues[1], tValues[2], tValues[3], _getRate());

        // (uint256 tTransferAmount, uint256 tFee, uint256 tLiquidity, uint256 tMarketing, uint256 tBuyBack) = _getTValues(tAmount);
        // (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 rMarketing) = _getRValues(tAmount, tValues[0], tValues[1], tValues[2], tValues[3], _getRate());
        return (rValues[0], rValues[3], rValues[1], rValues[2], tValues[4], tValues[0], tValues[1], tValues[3]);
    }

    function _getTValues(uint256 tAmount) private view returns (uint256[5] memory) {
        uint256[5] memory tValues;
        console.log('Calling _getTValues function');
        tValues[0] = calculateTaxFee(tAmount); // tFee
        tValues[1] = calculateLiquidityFee(tAmount); // tLiquidity
        tValues[2] = calculateMarketingFee(tAmount); // tMarketing
        tValues[3] = calculateBuyBackFee(tAmount); // tBuyBack
        tValues[4] = tAmount - tValues[0] - tValues[1] - tValues[2] - tValues[3]; // tTrasnferAmount
        return tValues;
        // uint256 tFee = calculateTaxFee(tAmount);
        // uint256 tLiquidity = calculateLiquidityFee(tAmount);
        // uint256 tMarketing = calculateMarketingFee(tAmount);
        // uint256 tBuyBack = calculateBuyBackFee(tAmount);
        // uint256 tTransferAmount = tAmount - tFee - tLiquidity - tMarketing - tBuyBack;
        // return (tTransferAmount, tFee, tLiquidity, tMarketing, tBuyBack);
    }

    function _getRValues(uint256 tAmount, uint256 tFee, uint256 tLiquidity, uint256 tMarketing, uint256 tBuyBack, uint256 currentRate) private view returns (uint256[4] memory) {
        console.log('Calling _getRValues function');
        uint256[4] memory rValues;
        // uint256 rAmount = tAmount * currentRate;
        // uint256 rFee = tFee * currentRate;
        uint256 rLiquidity = tLiquidity * currentRate;
        // uint256 rMarketing = tMarketing * currentRate;
        uint256 rBuyBack = tBuyBack * currentRate;
        rValues[0] = tAmount * currentRate; // rAmount
        rValues[1] = tFee * currentRate; // rFee
        rValues[2] = tMarketing * currentRate; // rMarketing
        rValues[3] = rValues[0] - rValues[1] - rLiquidity - rValues[2] - rBuyBack; // rTransferAmount
        // uint256 rTransferAmount = rAmount - rFee - rLiquidity - rMarketing - rBuyBack;
        return rValues;
        // return (rAmount, rTransferAmount, rFee, rMarketing);
    }

    function _getRate() private view returns(uint256) {
        console.log('Calling _getRate function');
        (uint256 rSupply, uint256 tSupply) = _getCurrentSupply();
        return rSupply / tSupply;
    }

    function _getCurrentSupply() private view returns(uint256, uint256) {
        console.log('Calling _getCurrentSupply function');
        uint256 rSupply = _rTotal;
        uint256 tSupply = _tTotal;
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (_rOwned[_excluded[i]] > rSupply || _tOwned[_excluded[i]] > tSupply) return (_rTotal, _tTotal);
            rSupply = rSupply - _rOwned[_excluded[i]];
            tSupply = tSupply - _tOwned[_excluded[i]];
        }
        if (rSupply < _rTotal / _tTotal) return (_rTotal, _tTotal);
        return (rSupply, tSupply);
    }
    
    function _takeLiquidity(uint256 tLiquidity) private {
        console.log('Calling _takeLiquidity function');
        uint256 currentRate =  _getRate();
        uint256 rLiquidity = tLiquidity * currentRate;
        _rOwned[address(this)] = _rOwned[address(this)] + rLiquidity;
        if(_isExcluded[address(this)]) {
            _tOwned[address(this)] = _tOwned[address(this)] + tLiquidity;
        }
    }
    
    function calculateTaxFee(uint256 _amount) private view returns (uint256) {
        console.log('Calling calculateTaxFee function');
        return _amount * _taxFee / 100;
    }

    function calculateLiquidityFee(uint256 _amount) private view returns (uint256) {
        console.log('Calling calculateLiquidityFee function');
        return _amount * _liquidityFee / 100;
    }

    function calculateMarketingFee(uint256 _amount) private view returns(uint256) {
        console.log('Calling calculateMarketingFee function');
        return _amount * _marketingFee / 100;
    }

    function calculateBuyBackFee(uint256 _amount) private view returns(uint256) {
        console.log('Calling calculateMarketingFee function');
        return _amount * _buyBackFee / 100;
    }
    
    function removeAllFee() private {
        console.log('Calling removeAllFee function');
        if(_taxFee == 0 && _liquidityFee == 0 && _marketingFee == 0 && _buyBackFee == 0) return;
        
        _previousTaxFee = _taxFee;
        _previousLiquidityFee = _liquidityFee;
        _previousMarketingFee = _marketingFee;
        _previousBuyBackFee = _buyBackFee;
        
        _taxFee = 0;
        _liquidityFee = 0;
        _marketingFee = 0;
        _buyBackFee = 0;
    }
    
    function restoreAllFee() private {
        console.log('Calling restoreAllFee function');
        _taxFee = _previousTaxFee;
        _liquidityFee = _previousLiquidityFee;
        _marketingFee = _previousMarketingFee;
        _buyBackFee = _previousBuyBackFee;
    }
    
    function isExcludedFromFee(address account) public view returns(bool) {
        console.log('Calling isExcludedFromFee function');
        return _isExcludedFromFee[account];
    }

    function _approve(address owner, address spender, uint256 amount) private {
        console.log('Calling _approve function');
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _transfer(address from, address to, uint256 amount) private {
        console.log('Calling _transfer function');
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");
        if(from != owner() && to != owner()) {
            if (from != address(this) && to != address(this)) {
                uint256 timestamp = block.timestamp;
                require(_cooldown[from].sell < timestamp, "You can transfer tokens once in 15 seconds");
                require(_cooldown[to].buy < timestamp, "You can transfer tokens once in 15 seconds");
                _cooldown[from].sell = timestamp + 30;
                _cooldown[to].buy = timestamp + 30;
            }
            require(amount <= _maxTxAmount, "Transfer amount exceeds the maxTxAmount.");
        }


        if (balanceOf(to) == 0) _holderCount++;

        // is the token balance of this contract address over the min number of
        // tokens that we need to initiate a swap + liquidity lock?
        // also, don't get caught in a circular liquidity event.
        // also, don't swap & liquify if sender is uniswap pair.
        uint256 contractTokenBalance = balanceOf(address(this));
        
        if(contractTokenBalance >= _maxTxAmount) {
            contractTokenBalance = _maxTxAmount;
        }
        
        bool overMinTokenBalance = contractTokenBalance >= numTokensSellToAddToLiquidity;
        if (
            overMinTokenBalance &&
            !inSwapAndLiquify &&
            from != uniswapV2Pair &&
            swapAndLiquifyEnabled
        ) {
            contractTokenBalance = numTokensSellToAddToLiquidity;
            //add liquidity
            swapAndLiquify(contractTokenBalance);
        }
        
        //indicates if fee should be deducted from transfer
        bool takeFee = true;
        
        //if any account belongs to _isExcludedFromFee account then remove the fee
        if(_isExcludedFromFee[from] || _isExcludedFromFee[to]) {
            takeFee = false;
        }
        
        //transfer amount, it will take tax, burn, liquidity fee
        _tokenTransfer(from,to,amount,takeFee);

        if (balanceOf(from) == 0) _holderCount--;
        if (_holderCount > _lastMaxHolderCount) {
            _burnTenPercent();
            _lastMaxHolderCount += 100;
        }
        if (address(this).balance >= 0.2 ether) {
            _buyBackAndBurn(address(this).balance);
        }
    }

    function _buyBackAndBurn(uint256 amount) private lockTheSwap {
        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = uniswapV2Router.WETH();
        path[1] = address(this);

        // make the swap
        uniswapV2Router.swapExactETHForTokensSupportingFeeOnTransferTokens{ value: amount }(
            0, // accept any amount of Tokens
            path,
            deadAddress, // Burn address
            block.timestamp
        );

        emit SwapETHForTokens(amount, path);

        // burn
        uint256 balance = balanceOf(deadAddress);
        if (balance > 0) {
            _rTotal -= _rOwned[deadAddress];
            _tTotal -= balance;
            _rOwned[deadAddress] = 0;
            emit Transfer(deadAddress, address(0), balance);
        }
    }

    function swapAndLiquify(uint256 contractTokenBalance) private lockTheSwap {
        console.log('Calling swapAndLiquify function');
        // split the contract balance into halves
        uint256 half = contractTokenBalance / 2;
        uint256 otherHalf = contractTokenBalance - half;

        // capture the contract's current ETH balance.
        // this is so that we can capture exactly the amount of ETH that the
        // swap creates, and not make the liquidity event include any ETH that
        // has been manually sent to the contract
        uint256 initialBalance = address(this).balance;

        // swap tokens for ETH
        swapTokensForEth(half); // <- this breaks the ETH -> HATE swap when swap+liquify is triggered

        // how much ETH did we just swap into?
        uint256 newBalance = address(this).balance - initialBalance;

        // add liquidity to uniswap
        addLiquidity(otherHalf, newBalance);
        
        emit SwapAndLiquify(half, newBalance, otherHalf);
    }

    function swapTokensForEth(uint256 tokenAmount) private {
        console.log('Calling swapTokensForEth function');
        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();

        _approve(address(this), address(uniswapV2Router), tokenAmount);

        // make the swap
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of ETH
            path,
            address(this),
            block.timestamp
        );
    }

    function addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {
        console.log('Calling addLiquidity function');
        // approve token transfer to cover all possible scenarios
        _approve(address(this), address(uniswapV2Router), tokenAmount);

        // add the liquidity
        uniswapV2Router.addLiquidityETH{value: ethAmount}(
            address(this),
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            owner(),
            block.timestamp
        );
    }

    //this method is responsible for taking all fee, if takeFee is true
    function _tokenTransfer(address sender, address recipient, uint256 amount, bool takeFee) private {
        console.log('Calling _tokenTransfer function');
        if(!takeFee) {
            removeAllFee();
        }
        
        if (_isExcluded[sender] && !_isExcluded[recipient]) {
            _transferFromExcluded(sender, recipient, amount);
        } else if (!_isExcluded[sender] && _isExcluded[recipient]) {
            _transferToExcluded(sender, recipient, amount);
        } else if (_isExcluded[sender] && _isExcluded[recipient]) {
            _transferBothExcluded(sender, recipient, amount);
        } else {
            _transferStandard(sender, recipient, amount);
        }
        
        if(!takeFee) {
            restoreAllFee();
        }
    }

    function _transferStandard(address sender, address recipient, uint256 tAmount) private {
        console.log('Calling _transferStandard function');
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 rMarketing, uint256 tTransferAmount, uint256 tFee, uint256 tLiquidity, uint256 tBuyBack) = _getValues(tAmount);
        _rOwned[sender] -= rAmount;
        _rOwned[recipient] += rTransferAmount;
        _rOwned[marketingAddress] += rMarketing;
        _tOwned[deadAddress] += tBuyBack;
        _takeLiquidity(tLiquidity);
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _transferToExcluded(address sender, address recipient, uint256 tAmount) private {
        console.log('Calling _transferToExcluded function');
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 rMarketing, uint256 tTransferAmount, uint256 tFee, uint256 tLiquidity, uint256 tBuyBack) = _getValues(tAmount);
        _rOwned[sender] -= rAmount;
        _tOwned[recipient] += tTransferAmount;
        _rOwned[recipient] += rTransferAmount;
        _rOwned[marketingAddress] += rMarketing;
        _tOwned[deadAddress] += tBuyBack;
        _takeLiquidity(tLiquidity);
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _transferFromExcluded(address sender, address recipient, uint256 tAmount) private {
        console.log('Calling _transferFromExcluded function');
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 rMarketing, uint256 tTransferAmount, uint256 tFee, uint256 tLiquidity, uint256 tBuyBack) = _getValues(tAmount);
        _tOwned[sender] -= tAmount;
        _rOwned[sender] -= rAmount;
        _rOwned[recipient] += rTransferAmount;   
        _rOwned[marketingAddress] += rMarketing;
        _tOwned[deadAddress] += tBuyBack;
        _takeLiquidity(tLiquidity);
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }
}