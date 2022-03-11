// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

import "@openzeppelin/contracts-ethereum-package/contracts/access/Ownable.sol";

import "../interfaces/IUniswapV2Pair.sol";
import "../interfaces/IBasisAsset.sol";
import "../interfaces/IOracle.sol";

contract Oracle is OwnableUpgradeSafe, IOracle {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    uint256 private constant PRICE_PRECISION = 1e6;

    address public asset;
    address public collateral;
    address public pair;
    uint256 public minAssetPrice;
    uint256 public minReserve;

    // Number of decimals needed to get to 18
    uint256 private missing_decimals; // =12

    /* ========== EVENTS ========== */

    event PairUpdated(address indexed newPair);
    event MinAssetPriceUpdated(uint256 value);
    event MinReserveUpdated(uint256 value);

    /* ========== GOVERNANCE ========== */

    function initialize(
        address _asset,
        address _collateral,
        address _pair,
        uint256 _minAssetPrice,
        uint256 _minReserve
    ) external initializer {
        address _token0 = IUniswapV2Pair(_pair).token0();
        address _token1 = IUniswapV2Pair(_pair).token1();
        if (_asset == _token0) {
            require(_collateral == _token1, "wrong pair");
        } else {
            require(_collateral == _token0 && _asset == _token1, "wrong pair");
        }

        OwnableUpgradeSafe.__Ownable_init();

        asset = _asset;
        collateral = _collateral;
        pair = _pair;
        minAssetPrice = _minAssetPrice;
        minReserve = _minReserve;

        missing_decimals = uint256(18).sub(uint256(IBasisAsset(_collateral).decimals()));
    }

    function setPair(address _pair) external onlyOwner {
        address _token0 = IUniswapV2Pair(_pair).token0();
        address _token1 = IUniswapV2Pair(_pair).token1();
        if (asset == _token0) {
            require(collateral == _token1, "wrong pair");
        } else {
            require(collateral == _token0 && asset == _token1, "wrong pair");
        }
        pair = _pair;
        emit PairUpdated(_pair);
    }

    function setMinReserve(uint256 _minReserve) external onlyOwner {
        minReserve = _minReserve;
        emit MinReserveUpdated(_minReserve);
    }

    function setMinPrice(uint256 _minAssetPrice) external onlyOwner {
        minAssetPrice = _minAssetPrice;
        emit MinAssetPriceUpdated(_minAssetPrice);
    }

    /* ========== VIEW FUNCTIONS ========== */

    function consult() external view override returns (uint256 _price) {
        _price = consultTrue();
        if (_price < minAssetPrice) {
            _price = minAssetPrice;
        }
    }

    function consultTrue() public view override returns (uint256 _price) {
        (uint256 _assetRes, uint256 _collateralRes) = getReserves(asset, collateral, pair);
        if (_collateralRes < minReserve) return 1;
        uint256 _collateralResFull = _collateralRes.mul(10 ** missing_decimals);
        _price = _collateralResFull.mul(PRICE_PRECISION).div(_assetRes);
    }

    /* ========== LIBRARIES ========== */

    function getReserves(address _tokenA, address _tokenB, address _pair) public view returns (uint256 _reserveA, uint256 _reserveB) {
        address _token0 = IUniswapV2Pair(_pair).token0();
        address _token1 = IUniswapV2Pair(_pair).token1();
        (uint112 _reserve0, uint112 _reserve1, ) = IUniswapV2Pair(_pair).getReserves();
        if (_token0 == _tokenA) {
            if (_token1 == _tokenB) {
                _reserveA = uint256(_reserve0);
                _reserveB = uint256(_reserve1);
            }
        } else if (_token0 == _tokenB) {
            if (_token1 == _tokenA) {
                _reserveA = uint256(_reserve1);
                _reserveB = uint256(_reserve0);
            }
        }
    }

    function getRatio(address _tokenA, address _tokenB, address _pair) public view returns (uint256 _ratioAoB) {
        (uint256 _reserveA, uint256 _reserveB) = getReserves(_tokenA, _tokenB, _pair);
        if (_reserveA > 0 && _reserveB > 0) {
            _ratioAoB = _reserveA.mul(1e18).div(_reserveB);
        }
    }

    /* ========== EMERGENCY ========== */

    function rescueStuckErc20(address _token) external onlyOwner {
        IERC20(_token).transfer(owner(), IERC20(_token).balanceOf(address(this)));
    }
}
