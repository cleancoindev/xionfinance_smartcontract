pragma solidity ^0.5.16;

interface IVesting {
    function initializeVesting(
        address _tokenContract,
        address[] calldata _beneficiaries,
        uint256 _reserveAmount,
        uint256[] calldata _amountsFounders,
        uint256[] calldata _amountsTeam,
        uint256[] calldata _amountsCommunity,
        uint256 _undistributedCommunityTokens,
        uint256 _undistributedTeamTokens,
        address _owner
    ) external returns (bool);
}
