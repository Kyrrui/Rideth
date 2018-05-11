pragma solidity ^0.4.17;

contract RideRequestFactory {
    address[] public rideRequests;

    function createRideRequest(uint _prePayment, uint _postPayment, 
                int _curLatitude, uint _curLatitudeDecimal,int _curLongitude, 
                uint _curLongitudeDecimal, int _destLatitude, 
                uint _destLatitudeDecimal, int _destLongitude, 
                uint _destLongitudeDecimal) public payable {
        RideRequest newRideRequest = new RideRequest(_prePayment, _postPayment, 
        _curLatitude, _curLatitudeDecimal, _curLongitude, _curLongitudeDecimal,
        _destLatitude, _destLatitudeDecimal, _destLongitude, 
        _destLongitudeDecimal, msg.sender);
        newRideRequest.initializeRideRequest.value(msg.value)();
        rideRequests.push(newRideRequest);
    }

    function getRideRequests() public view returns (address[]) {
        return rideRequests;
    }
}

contract RideRequest {
    
    enum State { CREATED, INITIALIZED, ACCEPTED, STARTED, COMPLETED, CANCELLED, REFUNDED }
    
    struct Coordinate {
        int latitude;
        uint latitudeDecimal;
        int longitude;
        uint longitudeDecimal;
    }
    
    // Destination Coordinates
    Coordinate public destination;
    
    // Requester
    address public requester;
    Coordinate public requesterLocation;

    // Selected drive offer
    address public driver;
    Coordinate public driverLocation;

    // Available drive offers
    address[] public possibleDrivers;
    mapping (address => Coordinate) public possibleDriversLocations;

    // Payment
    uint public preTripPayment;
    uint public postTripPayment;
    
    // State of contract
    State public state;
    
    uint MAX_OFFERS = 5; 
    uint NOT_AN_OFFER = 9999;

    constructor(uint _prePayment, uint _postPayment, int _curLatitude, 
                uint _curLatitudeDecimal,int _curLongitude, 
                uint _curLongitudeDecimal, int _destLatitude, 
                uint _destLatitudeDecimal, int _destLongitude, 
                uint _destLongitudeDecimal, address _requester) public payable {
        preTripPayment = _prePayment;
        postTripPayment = _postPayment;

        Coordinate memory curLocation = Coordinate({
            latitude: _curLatitude,
            latitudeDecimal: _curLatitudeDecimal,
            longitude: _curLongitude,
            longitudeDecimal: _curLongitudeDecimal
        });
        
        requester = _requester;
        requesterLocation = curLocation;
        
        destination = Coordinate({
            latitude: _destLatitude,
            latitudeDecimal: _destLatitudeDecimal,
            longitude: _destLongitude,
            longitudeDecimal: _destLongitudeDecimal
        });
    
        state = State.CREATED;
    }
    
    //////////////////////////////
    //// Requester Functions ////
    ////////////////////////////
    
    /**
     * Initializes the contract with ether.
     */
    function initializeRideRequest() public payable {
        require(msg.value >= preTripPayment + postTripPayment);
        require(state == State.CREATED);
        state = State.INITIALIZED;
    }
    
    /**
     * Called by the requester to signify the ride has been COMPLETED,
     * and unlocks post payment for the driver.
     */
    function completeRide() public requesterAccess {
        require(state == State.STARTED);
        state = State.COMPLETED;
    }
    
    /**
     * Called by the requester to start the ride when in the driver's car, 
     * gives the driver the pre-payment and locks the post payment
     * NOTE: Only a refund can given the requester his payment back from here.
     */
    function startRide() public requesterAccess {
        require(state == State.ACCEPTED);
        // Give the driver the pre-payment for pickup
        driver.transfer(preTripPayment);
        state = State.STARTED;
    }
    
    /**
     * Called by the requester to accept a driver offer.
     */
    function acceptDriverOffer(uint _driverChoice) public requesterAccess {
        address driverAddress = possibleDrivers[_driverChoice];
        require(isDriver(driverAddress) && state == State.INITIALIZED);
        driver = possibleDrivers[_driverChoice];
        driverLocation = possibleDriversLocations[driverAddress];
        state = State.ACCEPTED;
    }
    
    /**
     * Called by ride requester before an offer is ACCEPTED to cancel the 
     * request and refund all ether OR when the request has been REFUNDED by
     * the driver.
     */
    function cancelRequest() public requesterAccess {
        require(state == State.INITIALIZED 
                || state == State.REFUNDED 
                || state == State.CREATED);
        selfdestruct(requester);
    }
    
    
    //////////////////////////////
    ///// Driver Functions //////
    ////////////////////////////
    
    /**
     * While contract is in the CREATED state, a driver can create 
     * a drive offer with their current location.
     */
    function createDriveOffer(int _curLatitude, uint _curLatitudeDecimal, 
                              int _curLongitude, uint _curLongitudeDecimal) 
                              public {
        require(possibleDrivers.length < MAX_OFFERS 
                && !isDriver(msg.sender) 
                && state == State.INITIALIZED);
        
        Coordinate memory curLocation = Coordinate({
            latitude: _curLatitude,
            latitudeDecimal: _curLatitudeDecimal,
            longitude: _curLongitude,
            longitudeDecimal: _curLongitudeDecimal
        });
        
        possibleDrivers.push(msg.sender);
        possibleDriversLocations[msg.sender] = curLocation;
    }
    
    /**
     * Called by a driver who has made an offer that has yet to be STARTED
     * removes offer from offer list.
     */
    function cancelDriveOffer() public {
        uint indexOfOffer = findDriveOffer(msg.sender);
        require(state == State.INITIALIZED && indexOfOffer != NOT_AN_OFFER);
        removeDriveOffer(indexOfOffer);
    }
    
    /**
     * Called by the driver when he is unable to fufill the contract.
     * Refunds the requester.
     */
    function refundRequest() public driverAccess {
        state = State.REFUNDED;
    }
    
    /**
     * Called by the driver when the ride is COMPLETED, withdrawing remaining
     * ETH from contract.
     */
    function recievePayment() public driverAccess {
        require(state == State.COMPLETED);
        selfdestruct(driver);
    }
    
    ///////////////////////////////////
    //// Private Helper Functions ////
    /////////////////////////////////
    
    /**
     * Checks if given address has a drive offer in the drive offer list
     */
    function isDriver(address _driverAddress) private view returns(bool) {
        bool isADriver = false;
        uint indexOfOffer = findDriveOffer(_driverAddress);
        if (indexOfOffer != NOT_AN_OFFER) {
            isADriver = true;
        }
        return isADriver;
    }
    
    /**
     * Find the driver offer in the possibleDriver list 
     * or return NOT_AN_OFFER (== 9999)
     */
    function findDriveOffer(address _driverAddress) private view returns(uint) {
        for (uint i; i < possibleDrivers.length; i++) {
            if (possibleDrivers[i] == _driverAddress) {
                return i;
            }
        }
        return NOT_AN_OFFER;
    }
    
    /**
     * Remove driver offer from the possibleDrivers list
     */
    function removeDriveOffer(uint index) private {
        require(index < possibleDrivers.length);
        for (uint i = index; i<possibleDrivers.length-1; i++){
            possibleDrivers[i] = possibleDrivers[i+1];
        }
        possibleDrivers.length--;
    }
    
    //////////////////////////////
    //////// Modifiers //////////
    ////////////////////////////
    
    modifier requesterAccess {
        require(msg.sender == requester);
        _;
    }
    
    modifier driverAccess {
        require(msg.sender == driver);
        _;
    }
    
}