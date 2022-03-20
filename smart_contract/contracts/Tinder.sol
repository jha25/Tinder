//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Tinder {
    enum Gender {
        Male,
        Female
    }
    enum SwipeStatus {
        Unknown,
        Like,
        Dislike
    }
    struct User {
        string name;
        string city;
        Gender gender;
        uint256 age;
        string picUrl;
    }
    struct SwipeSession {
        uint256 start;
        uint256 count;
    }
    mapping(address => User) private users;
    mapping(bytes32 => mapping(uint256 => address[])) private userIdsByCity;
    mapping(address => mapping(address => SwipeStatus)) private swipes;
    mapping(address => SwipeSession) private swipeSessions;

    event NewMatch(address indexed from, address indexed to, uint256 date);

    event NewMessage(
        address indexed from,
        address indexed to,
        string content,
        uint256 date
    );

    modifier userExists(address _userId) {
        require(users[_userId].age > 0, "User is not registered");
        _;
    }

    function isEmptyString(string memory _str) internal pure returns (bool) {
        bytes memory bytesStr = bytes(_str);
        return bytesStr.length == 0;
    }

    function register(
        string calldata _name,
        string calldata _city,
        Gender _gender,
        uint256 _age,
        string calldata _picUrl
    ) external {
        require(users[msg.sender].age == 0, "User is already registered");
        require(!isEmptyString(_name), "Name cannot be empty");
        require(!isEmptyString(_city), "City cannot be empty");
        require(_age > 17, "Age must be 18 or above");
        require(!isEmptyString(_picUrl), "Pic Url cannot be empty");
        users[msg.sender] = User(_name, _city, _gender, _age, _picUrl);
        userIdsByCity[keccak256(abi.encodePacked((_city)))][uint256(_gender)]
            .push(msg.sender);
    }

    function getMatchableUsers()
        external
        view
        userExists(msg.sender)
        returns (User[] memory)
    {
        User storage user = users[msg.sender];
        uint256 oppositeGender = user.gender == Gender.Male ? 1 : 0;
        address[] storage userIds = userIdsByCity[
            keccak256(abi.encodePacked(user.city))
        ][oppositeGender];

        uint256 matchableUserCount;
        for (uint256 i = 0; i < userIds.length; i++) {
            address userId = userIds[i];
            if (swipes[msg.sender][userId] == SwipeStatus.Unknown) {
                matchableUserCount++;
            }
        }

        User[] memory _users = new User[](matchableUserCount);
        for (uint256 i = 0; i < matchableUserCount; i++) {
            address userId = userIds[i];
            if (swipes[msg.sender][userId] == SwipeStatus.Unknown) {
                _users[i] = users[userId];
            }
        }
        return _users;
    }

    function swipe(SwipeStatus _swipeStatus, address _userId)
        external
        userExists(msg.sender)
        userExists(_userId)
    {
        require(
            swipes[msg.sender][_userId] == SwipeStatus.Unknown,
            "Can not swipe the same person twice"
        );

        SwipeSession storage swipeSession = swipeSessions[msg.sender];
        if (swipeSession.start + 86400 <= block.timestamp) {
            swipeSession.start = block.timestamp;
            swipeSession.count = 100;
        }
        require(
            swipeSession.count <= 100,
            "You have already used up all your swipes for the day"
        );
        swipeSession.count++;

        if (_swipeStatus == SwipeStatus.Dislike) {
            swipes[msg.sender][_userId] = _swipeStatus;
            return;
        }
        swipes[msg.sender][_userId] = SwipeStatus.Like;
        if (swipes[_userId][msg.sender] == SwipeStatus.Like) {
            emit NewMatch(msg.sender, _userId, block.timestamp);
        }
    }

    function sendMessage(address _to, string calldata _content)
        external
        userExists(msg.sender)
        userExists(_to)
    {
        require(
            swipes[msg.sender][_to] == SwipeStatus.Like &&
                swipes[_to][msg.sender] == SwipeStatus.Like,
            "Both user needs to match to send message"
        );
        emit NewMessage(msg.sender, _to, _content, block.timestamp);
    }
}
