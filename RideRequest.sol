pragma solidity ^0.4.0;
contract RideRequest {
    
    struct Coordinate {
        int latitude;
        int longitude;
    }
    
    struct Requester {
        address requesterAddress;
        Coordinate location;
    }
    
    struct DriverOffer {
        address driverAddress;
        Coordinate location;
    }
    
    Requester public requester;
    DriverOffer public driverOffer;
    DriverOffer[] public driverOffers;
    uint public payment;
    Coordinate public destination;
    uint public expirationTime;
    bool rideAccepted;
    bool rideStarted;
    
    uint MAX_OFFERS = 5;
    uint EXPIRATION_DURATION = 5 minutes;
    
    constructor(int _curLatitude, int _curLongitude, int _destLatitude, 
                int _destLongitude) public payable {
        Coordinate memory curLocation = Coordinate({
            latitude: _curLatitude, 
            longitude: _curLongitude
        });
        
        requester = Requester ({
            location: curLocation,
            requesterAddress: msg.sender
        });
        
        destination = Coordinate({
            latitude: _destLatitude,
            longitude: _destLongitude
        });
        
        payment = msg.value;
        expirationTime = now + EXPIRATION_DURATION;
        rideAccepted = false;
        rideStarted = false;
    }
    
    function requestDriverRole(int _curLatitude, int _curLongitude) public checkExpiration {
        require(driverOffers.length < MAX_OFFERS && !isDriver(msg.sender));
        
        Coordinate memory curLocation = Coordinate({
            latitude: _curLatitude, 
            longitude: _curLongitude
        });
        
        DriverOffer memory newOffer = DriverOffer({
            driverAddress: msg.sender,
            location: curLocation
        });
        driverOffers.push(newOffer);
    }
    
    function isDriver(address _driverAddress) private view returns(bool) {
        bool isDriver = false;
        for (uint i; i < driverOffers.length; i++) {
            if (driverOffers[i].driverAddress == _driverAddress) {
                isDriver = true;
            }
        }
        return isDriver;
    }
    
    function extendExpiration() public requesterAccess {
        expirationTime = now + EXPIRATION_DURATION;
    }
    
    function removeRequest() public requesterAccess {
        require(!rideAccepted);
        selfdestruct(requester.requesterAddress);
    }
    
    modifier requesterAccess {
        require(msg.sender == requester.requesterAddress);
        _;
    }
    
    modifier checkExpiration {
        if (!rideStarted) {
            if (expirationTime > now) {
                selfdestruct(requester.requesterAddress);
            }
        }
        _;
    }
    
}

contract RidethIdentityProvider {}
