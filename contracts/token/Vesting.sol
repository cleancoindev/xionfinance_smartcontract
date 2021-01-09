pragma solidity ^0.5.16;

import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "@openzeppelin/upgrades/contracts/Initializable.sol";
import "@openzeppelin/upgrades/contracts/ownership/Ownable.sol";
import "../interfaces/IXGTToken.sol";

contract Vesting is Initializable, OpenZeppelinUpgradesOwnable {
    using SafeMath for uint256;
    IXGTToken public xgtToken;

    struct Beneficiary {
        uint256 totalTokens;
        uint256 tokensLeft;
        uint256 claimedTokens;
        uint256 intervalNumber;
    }

    mapping(address => Beneficiary) internal beneficiary;
    address[] internal beneficiaries;

    uint256 public deployment; // Time of deployment of this contract
    uint256 public constant trancheIntervals = (365 * 24 * 60 * 60) / 12; // 1 Month in Seconds
    uint256 public constant totalIntervals = 24; // Spread over 24 months

    uint256 public totalVestedTokens;

    uint256 public undistributedTokenInterval;

    uint256 public totalUndistributedCommunityTokens;
    uint256 public totalUnlockedCommunityTokens;
    uint256 public distributedCommunityTokens;

    uint256 public totalUndistributedTeamTokens;
    uint256 public totalUnlockedTeamTokens;
    uint256 public distributedTeamTokens;

    function initialize(
        address _tokenContract,
        address[] memory _beneficiaries,
        uint256[] memory _amounts,
        uint256 _undistributedCommunityTokens,
        uint256 _undistributedTeamTokens
    ) public initializer returns (bool) {
        require(
            _beneficiaries.length == _amounts.length,
            "VESTING-ARRAY-LENGTH-MISMATCH"
        );
        xgtToken = IXGTToken(_tokenContract);
        deployment = now;
        for (uint256 i = 0; i < _beneficiaries.length; i++) {
            beneficiary[_beneficiaries[i]] = Beneficiary(_amounts[i], 0, 0, 0);
            beneficiaries.push(_beneficiaries[i]);
            totalVestedTokens = totalVestedTokens.add(_amounts[i]);
        }
        totalVestedTokens = totalVestedTokens
            .add(_undistributedCommunityTokens)
            .add(_undistributedTeamTokens);

        totalUndistributedCommunityTokens = _undistributedCommunityTokens;
        totalUndistributedTeamTokens = _undistributedTeamTokens;

        require(
            xgtToken.balanceOf(address(this)) == totalVestedTokens,
            "VESTING-TOKENS-MISMATCH"
        );
        return true;
    }

    function distributeTeamTokens(address _receiver, uint256 _amount)
        external
        onlyOwner
    {
        require(_amount > 0, "VESTING-CANT-VEST-ZERO-AMOUNT");
        require(
            freeTeamTokens() >= _amount,
            "VESTING-NOT-ENOUGH-TEAM-TOKENS-UNLOCKED"
        );

        distributedTeamTokens = distributedTeamTokens.add(_amount);
        require(
            xgtToken.transfer(_receiver, _amount),
            "VESTING-TRANSFER-FAILED"
        );
    }

    function distributeCommunityTokens(address _receiver, uint256 _amount)
        external
        onlyOwner
    {
        require(_amount > 0, "VESTING-CANT-VEST-ZERO-AMOUNT");
        require(
            freeCommunityTokens() >= _amount,
            "VESTING-NOT-ENOUGH-COMMUNITY-TOKENS-UNLOCKED"
        );

        distributedCommunityTokens = distributedCommunityTokens.add(_amount);
        require(
            xgtToken.transfer(_receiver, _amount),
            "VESTING-TRANSFER-FAILED"
        );
    }

    function claim(address _beneficiary) public {
        require(
            beneficiary[_beneficiary].totalTokens > 0,
            "VESTING-BENEFICIARY-DOESNT-EXIST"
        );

        uint256 currentInterval = (now.sub(deployment)).div(trancheIntervals);

        if (currentInterval <= beneficiary[_beneficiary].intervalNumber) {
            return;
        }

        uint256 claimedAmount = 0;
        if (currentInterval == totalIntervals) {
            claimedAmount = beneficiary[_beneficiary].tokensLeft;
            beneficiary[_beneficiary].intervalNumber = totalIntervals;
            beneficiary[_beneficiary].claimedTokens = beneficiary[_beneficiary]
                .claimedTokens
                .add(beneficiary[_beneficiary].tokensLeft);
            beneficiary[_beneficiary].tokensLeft = 0;
            require(
                beneficiary[_beneficiary].totalTokens ==
                    beneficiary[_beneficiary].claimedTokens.add(
                        beneficiary[_beneficiary].tokensLeft
                    ),
                "VESTING-SUM-MISMATCH"
            );
        } else {
            uint256 intervalDiff =
                currentInterval.sub(beneficiary[_beneficiary].intervalNumber);
            beneficiary[_beneficiary].intervalNumber = currentInterval;
            uint256 amountPerInterval =
                beneficiary[_beneficiary].totalTokens.div(totalIntervals);
            claimedAmount = amountPerInterval.mul(intervalDiff);
            beneficiary[_beneficiary].claimedTokens = beneficiary[_beneficiary]
                .claimedTokens
                .add(claimedAmount);
            beneficiary[_beneficiary].tokensLeft = beneficiary[_beneficiary]
                .tokensLeft
                .sub(claimedAmount);
            xgtToken.transfer(_beneficiary, claimedAmount);
        }
        require(
            xgtToken.transfer(_beneficiary, claimedAmount),
            "VESTING-TRANSFER-FAILED"
        );
    }

    function claimAll() external {
        for (uint256 i = 0; i < beneficiaries.length; i++) {
            claim(beneficiaries[i]);
        }
        unlockTokens();
    }

    function unlockTokens() public {
        uint256 currentInterval = (now.sub(deployment)).div(trancheIntervals);

        if (currentInterval <= undistributedTokenInterval) {
            return;
        }

        uint256 unlockedAmountTeam = 0;
        uint256 unlockedAmountCommunity = 0;
        if (currentInterval == totalIntervals) {
            unlockedAmountTeam = totalUndistributedTeamTokens.sub(
                totalUnlockedTeamTokens
            );
            unlockedAmountCommunity = totalUndistributedCommunityTokens.sub(
                totalUnlockedCommunityTokens
            );
            totalUnlockedTeamTokens = totalUndistributedTeamTokens;
            totalUnlockedCommunityTokens = totalUndistributedCommunityTokens;
            undistributedTokenInterval = totalIntervals;
        } else {
            uint256 intervalDiff =
                currentInterval.sub(undistributedTokenInterval);
            undistributedTokenInterval = currentInterval;
            uint256 amountTeam =
                (totalUndistributedTeamTokens.div(totalIntervals)).mul(
                    intervalDiff
                );
            uint256 amountCommunity =
                (totalUndistributedCommunityTokens.div(totalIntervals)).mul(
                    intervalDiff
                );
            totalUnlockedCommunityTokens = totalUnlockedCommunityTokens.add(
                amountCommunity
            );
            totalUnlockedTeamTokens = totalUnlockedTeamTokens.add(amountTeam);
        }
    }

    function updateAddress(address _old, address _new) external {
        require(
            beneficiary[_old].totalTokens > 0,
            "VESTING-BENEFICIARY-DOESNT-EXIST"
        );
        beneficiary[_new] = Beneficiary(
            beneficiary[_old].totalTokens,
            beneficiary[_old].tokensLeft,
            beneficiary[_old].claimedTokens,
            beneficiary[_old].intervalNumber
        );
        beneficiary[_old] = Beneficiary(0, 0, 0, 0);

        for (uint256 i = 0; i < beneficiaries.length; i++) {
            if (beneficiaries[i] == _old) {
                beneficiaries[i] = _new;
                break;
            }
        }
    }

    function getUnclaimedTokens(address _address)
        external
        view
        returns (uint256)
    {
        return beneficiary[_address].tokensLeft;
    }

    function getTotalTokens(address _address) external view returns (uint256) {
        return beneficiary[_address].totalTokens;
    }

    function getClaimedTokens(address _address)
        external
        view
        returns (uint256)
    {
        return beneficiary[_address].claimedTokens;
    }

    function freeTeamTokens() public view returns (uint256) {
        return totalUnlockedTeamTokens.sub(distributedTeamTokens);
    }

    function freeCommunityTokens() public view returns (uint256) {
        return totalUnlockedCommunityTokens.sub(distributedCommunityTokens);
    }
}
