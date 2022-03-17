// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

interface IOracle {
    function nextEpochPoint() external view returns (uint256);

    function update() external;

    function epochConsult() external view returns (uint256);

    function consult() external view returns (uint256);

    function consultTrue() external view returns (uint256);
}
