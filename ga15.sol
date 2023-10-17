// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract GlobalAidV2 {
    using SafeMath for uint256;

    address public owner;
    uint256 public defaultReferrerRate = 10; // Default referral rate is 10%
    uint256 public defaultOwnerRate = 10; // Default referral rate is 10%
    uint256 public totalUsers; // Total number of users

    struct RewardPool {
        uint256 rewardPoolId;
        string rewardPoolName;
        uint256 totalAmount;
        uint256 withdrawnNum;
        uint256 releaseRate;
        uint256 lastReleaseTime;
        uint256 activationCondition;
        bool rewardPoolStatus;
    }

    struct Pack {
        uint256 id;
        uint256 purchaseTime;
        bool isActive;
        RewardPool[] rewardPools;
    }

    mapping(address => address) public referrers;
    mapping(uint256 => Pack) public packs;
    mapping(address => uint256[]) public userPacks;
    mapping(address => uint256) public userTotalInvestment;
    mapping(address => uint256) public userTotalWithdrawn;
    mapping(address => uint256) public userLastActionTime;

    mapping(address => uint256) public referralEarnings;

    uint256 public packPrice = 500000000000000; // 0.0005 BNB in wei
    uint256 public packIdCounter = 1;
    address public defaultReferrer = 0x57a34Af3e29AA3339977B522414Ec473397C2B8a; // Set default referrer address

    event PackPurchased(address indexed user, uint256 indexed packId, uint256 value);
    event Withdraw(address indexed user, uint256 amount);

    constructor() {
        owner = msg.sender; // Set the contract deployer as the owner
        // Initialize reward pools
        packs[0].rewardPools.push(RewardPool(1, 'Beginner',        300000000000000000,  0, 7500000000000000, block.timestamp, 0, true));
        packs[0].rewardPools.push(RewardPool(2, 'Runner',          350000000000000000,  0, 8750000000000000, block.timestamp, 2, false));
        packs[0].rewardPools.push(RewardPool(3, 'Bronze',          467500000000000000,  0, 9350000000000000, block.timestamp, 4, false));
        packs[0].rewardPools.push(RewardPool(4, 'Silver',          750000000000000000, 0, 15000000000000000, block.timestamp, 6, false));
        packs[0].rewardPools.push(RewardPool(5, 'Gold',            1500000000000000000, 0, 25000000000000000, block.timestamp, 2000, false));
        packs[0].rewardPools.push(RewardPool(6, 'Platinum',        2625000000000000000, 0, 37500000000000000, block.timestamp, 5000, false));
        packs[0].rewardPools.push(RewardPool(7, 'Diamond',         5000000000000000000,  0, 62500000000000000, block.timestamp, 10000, false));
        packs[0].rewardPools.push(RewardPool(8, 'Blue Diamond',    9000000000000000000,  0, 112500000000000000, block.timestamp, 20000, false));
        packs[0].rewardPools.push(RewardPool(9, 'Entrepreneur',    13000000000000000000,  0, 162500000000000000, block.timestamp, 50000, false));
        packs[0].rewardPools.push(RewardPool(10, 'Chairman',       28125000000000000000, 0, 312500000000000000, block.timestamp, 60000, false));
        packs[0].rewardPools.push(RewardPool(11, 'Vice President', 42750000000000000000, 0, 475000000000000000, block.timestamp, 70000, false));
        packs[0].rewardPools.push(RewardPool(12, 'President',      90000000000000000000, 0, 750000000000000000, block.timestamp, 80000, false));
        packs[0].rewardPools.push(RewardPool(13, 'Chief',          187500000000000000000, 0, 1562500000000000000, block.timestamp, 90000, false));
        packs[0].rewardPools.push(RewardPool(14, 'King',           562500000000000000000, 0, 3750000000000000000, block.timestamp, 110000, false));
        packs[0].rewardPools.push(RewardPool(15, 'Avenger',        937500000000000000000, 0, 3750000000000000000, block.timestamp, 120000, false));
    }
    
    function _incrementTotalUsers() internal {
        totalUsers = totalUsers.add(1);
    }

    function purchasePacks(address referrer, uint256 numPacks) external payable {
        require(numPacks > 0, "Number of packs must be greater than zero");
        uint256 totalCost = packPrice.mul(numPacks);
        require(msg.value >= totalCost, "Insufficient funds to purchase packs");
        uint256 referralReward = (totalCost.mul(defaultReferrerRate)).div(100);
        uint256 ownerReward = (totalCost.mul(defaultOwnerRate)).div(100);
        uint256 packIdCounterEnd = packIdCounter.add(numPacks);

        for (uint256 i = packIdCounter; i < packIdCounterEnd; i++) {
            uint256 packId = packIdCounter;
            packIdCounter = packIdCounter.add(1);
            
            Pack storage newPack = packs[packId];
            newPack.id = packId;
            newPack.purchaseTime = block.timestamp;
            newPack.isActive = true;
            newPack.rewardPools = packs[0].rewardPools;

            userPacks[msg.sender].push(packId);
        }

        // Update referrer and send referral reward
        _updateReferrer(referrer, referralReward);

        // Send rewards to the owner and the referrer
        _transferWithCheck(owner, ownerReward);
        _transferWithCheck(referrers[msg.sender], referralReward);

        if (userTotalInvestment[msg.sender] == 0) {
                _incrementTotalUsers();
            }
        // Update user's total investment
        userTotalInvestment[msg.sender] = userTotalInvestment[msg.sender].add(totalCost);
        // Update user's last action time
        userLastActionTime[msg.sender] = block.timestamp;

        emit PackPurchased(msg.sender, packIdCounter.sub(numPacks), totalCost);
    }

    function _updateReferrer(address referrer, uint256 referralReward) internal {

        if (referrers[msg.sender] == address(0)) {
            if (referrer != msg.sender && userTotalInvestment[referrer] > 0) {
                referrers[msg.sender] = referrer;
                referralEarnings[referrer] = referralEarnings[referrer].add(referralReward);
            } else {
                referrers[msg.sender] = defaultReferrer;
                referralEarnings[defaultReferrer] = referralEarnings[defaultReferrer].add(referralReward);
            }
        }
                
        if (referrers[msg.sender] != address(0)) {
            referralEarnings[referrer] = referralEarnings[referrer].add(referralReward);
        }
        
    }

    function _transferWithCheck(address recipient, uint256 amount) internal {
        require(recipient != address(0), "Invalid recipient address");
        if (amount > 0 && recipient != address(0)) {
            payable(recipient).transfer(amount);
        }
    }

    function calculatePackRewards(uint256 packId) public view returns (uint256) {
        Pack storage pack = packs[packId];
        uint256 totalRewards = 0;

        for (uint256 i = 0; i < 15; i++) {
            RewardPool storage rewardPool = pack.rewardPools[i];
            if (pack.isActive && rewardPool.rewardPoolStatus) {
                uint256 startTime = rewardPool.lastReleaseTime;
                uint256 timeElapsed = block.timestamp - startTime;
                uint256 releaseAmount = (timeElapsed.mul(rewardPool.releaseRate)).div(86400);

                // If release amount exceeds the total amount, set it to the total amount
                if (releaseAmount > rewardPool.totalAmount) {
                    releaseAmount = rewardPool.totalAmount;
                }

                totalRewards = totalRewards.add(releaseAmount);
            }
        }

        return totalRewards;
    }

    function calculateTotalRewards(address user) public view returns (uint256) {
        uint256 totalRewards = 0;
        uint256[] memory userPacksList = userPacks[user];

        for (uint256 i = 0; i < userPacksList.length; i++) {
            totalRewards = totalRewards.add(calculatePackRewards(userPacksList[i]));
        }

        return totalRewards;
    }

    function activateRewardPools(uint256 packId) external {
        require(packId > 0 && packId <= packIdCounter, "Invalid pack ID");
        Pack storage pack = packs[packId];
        
        for (uint256 i = 0; i < 15; i++) {
            RewardPool storage rewardPool = pack.rewardPools[i];
            
            if (!rewardPool.rewardPoolStatus) {
                if ((packIdCounter - packId) >= rewardPool.activationCondition) {
                    rewardPool.rewardPoolStatus = true;
                    rewardPool.lastReleaseTime = block.timestamp;
                }
            }
        }
    }

    function activateAllEligiblePacksRewardPools() external {
        uint256[] storage userPackList = userPacks[msg.sender];

        for (uint256 i = 0; i < userPackList.length; i++) {
            uint256 packId = userPackList[i];
            Pack storage pack = packs[packId];
            
            for (uint256 j = 0; j < 15; j++) {
                RewardPool storage rewardPool = pack.rewardPools[j];

                if (!rewardPool.rewardPoolStatus) {
                    if ((packIdCounter - packId) >= rewardPool.activationCondition) {
                        rewardPool.rewardPoolStatus = true;
                        rewardPool.lastReleaseTime = block.timestamp;
                    }
                }
            }
        }
    }

    function withdraw() external {
        uint256 totalRewards = calculateTotalRewards(msg.sender);
        require(totalRewards > 0, "No rewards to withdraw");

        // Calculate tax based on the contract balance
        uint256 taxRate;
        uint256 contractBalance = address(this).balance;

        if (contractBalance < 100 ether) {
            taxRate = 50; // 50%
        } else if (contractBalance < 300 ether) {
            taxRate = 40; // 40%
        } else if (contractBalance < 600 ether) {
            taxRate = 30; // 30%
        } else if (contractBalance < 1000 ether) {
            taxRate = 20; // 20%
        } else if (contractBalance < 2000 ether) {
            taxRate = 10; // 10%
        } else {
            taxRate = 0; // 0%
        }

        uint256 taxAmount = (totalRewards.mul(taxRate)).div(100);
        uint256 payoutAmount = totalRewards.sub(taxAmount);

        uint256[] memory userPacksList = userPacks[msg.sender];

        for (uint256 i = 0; i < userPacksList.length; i++) {
            uint256 packId = userPacksList[i];
            Pack storage pack = packs[packId];

            for (uint256 j = 0; j < 15; j++) {
                if (pack.rewardPools[j].rewardPoolStatus) {
                    uint256 startTime = pack.rewardPools[j].lastReleaseTime;
                    uint256 timeElapsed = block.timestamp - startTime;
                    uint256 releaseAmount = (timeElapsed.mul(pack.rewardPools[j].releaseRate)).div(86400);
                    // If release amount exceeds the reward pool balance, set it to the balance
                    if (releaseAmount > pack.rewardPools[j].totalAmount) {
                        releaseAmount = pack.rewardPools[j].totalAmount;
                    }
                    pack.rewardPools[j].totalAmount = pack.rewardPools[j].totalAmount.sub(releaseAmount);
                    // Update the last release time for this reward pool
                    pack.rewardPools[j].lastReleaseTime = block.timestamp;
                    // Update withdrawnNum
                    pack.rewardPools[j].withdrawnNum = pack.rewardPools[j].withdrawnNum.add(releaseAmount);
                }
            }
        }

        userTotalWithdrawn[msg.sender] = userTotalWithdrawn[msg.sender].add(payoutAmount);
        userLastActionTime[msg.sender] = block.timestamp;

        // Send user's payout (excluding commission)
        payable(msg.sender).transfer(payoutAmount);

        emit Withdraw(msg.sender, payoutAmount);

        // Distribute referral commissions
        address referrer = referrers[msg.sender];
        if (referrer != address(0)) {
            uint256 referralAmount = (totalRewards.mul(10)).div(100);
            referralEarnings[referrer] = referralEarnings[referrer].add(referralAmount);
            payable(referrer).transfer(referralAmount);
        }
    }

    function ownerWithdraw(uint256 amount) external {
        require(msg.sender == owner, "Only the owner can call this function");
        require(address(this).balance >= amount, "Insufficient contract balance");

        payable(owner).transfer(amount);
    }

    // New function for querying referral earnings
    function getReferralEarnings(address user) external view returns (uint256) {
        return referralEarnings[user];
    }

    function getUserPacks(address user) external view returns (uint256[] memory) {
        return userPacks[user];
    }

    function getPackActivationStatus(uint256 packId) external view returns (bool[15] memory) {
        bool[15] memory poolStatus;

        for (uint256 i = 0; i < 15; i++) {
            poolStatus[i] = packs[packId].rewardPools[i].rewardPoolStatus;
        }

        return poolStatus;
    }

    function getUserInfo(address user) external view returns (uint256[] memory, uint256, uint256, uint256, uint256) {
        return (
            userPacks[user],
            userTotalInvestment[user],
            userTotalWithdrawn[user],
            userPacks[user].length,
            userLastActionTime[user]
        );
    }

    // New function for querying attributes of a single pack
    function getPackAttributes(uint256 packId) internal view returns (Pack memory) {
        return packs[packId];
    }

    // New function for querying attributes of packs owned by a user
    function getUserPackAttributes(address user) external view returns (Pack[] memory) {
        uint256[] memory packIds = userPacks[user];
        Pack[] memory packAttributes = new Pack[](packIds.length);

        for (uint256 i = 0; i < packIds.length; i++) {
            uint256 packId = packIds[i];
            packAttributes[i] = getPackAttributes(packId);
        }

        return packAttributes;
    }

    function getContractBalance() public view returns (uint256) {
        return address(this).balance;
    }

    // 检查 "packId" 是否有满足激活条件的 Rank
    function isPackEligibleForActivation(uint256 packId) public view returns (bool) {
        require(packId > 0 && packId <= packIdCounter, "Invalid pack ID");

        // 获取指定 "packId" 的 Pack
        Pack storage pack = packs[packId];

        // 遍历 Pack 中的奖励池
        for (uint256 i = 0; i < pack.rewardPools.length; i++) {
            RewardPool storage rewardPool = pack.rewardPools[i];
            if (!rewardPool.rewardPoolStatus) {
                // 获取奖励池的激活条件
                uint256 activationCondition = rewardPool.activationCondition;

                // 获取当前差值是否满足激活新Rank
                uint256 currentRank = packIdCounter.sub(packId);

                // 判断是否满足激活条件
                if (currentRank >= activationCondition) {
                    return true;
                }
            }
        }

        return false;
    }
}
