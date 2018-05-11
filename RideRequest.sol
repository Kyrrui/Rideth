pragma solidity ^0.4.17;
contract RideRequest {
    
    enum State { CREATED, ACCEPTED, STARTED, COMPLETED, CANCELLED, REFUNDED }
    
    struct Coordinate {
        int latitude;
        uint latitudeDecimal;
        int longitude;
        uint longitudeDecimal;
    }
    
    // It would be ideal to use structs, but currently tuples are not supported
    // in public calls :,(
    // struct Requester {
    //     address requesterAddress;
    //     Coordinate location;
    // }
    
    // Since tuples can be called internally, we will use this for keeping 
    // track of the list of drive offers
    struct DriverOffer {
        address driverAddress;
        Coordinate location;
    }
    
    // Destination Coordinates
    Coordinate public destination;
    
    // Requester
    // Requester public requester;
    address requester;
    Coordinate requesterLocation;
    
    // Selected drive offer
    // DriverOffer public driverOffer;
    address driver;
    Coordinate driverLocation;
    
    // Available drive offers
    DriverOffer[] public driverOffers;
    
    // Payment
    uint public payment;
    
    // State of contract
    State public state;
    
    uint MAX_OFFERS = 5; 
    uint NOT_AN_OFFER = 9999;

    constructor(int _curLatitude, uint _curLatitudeDecimal, int _curLongitude, 
                uint _curLongitudeDecimal, int _destLatitude, 
                uint _destLatitudeDecimal, int _destLongitude, 
                uint _destLongitudeDecimal) public payable {
                    
        Coordinate memory curLocation = Coordinate({
            latitude: _curLatitude,
            latitudeDecimal: _curLatitudeDecimal,
            longitude: _curLongitude,
            longitudeDecimal: _curLongitudeDecimal
        });
        
        requester = msg.sender;
        requesterLocation = curLocation;
        
        destination = Coordinate({
            latitude: _destLatitude,
            latitudeDecimal: _destLatitudeDecimal,
            longitude: _destLongitude,
            longitudeDecimal: _destLongitudeDecimal
        });
        
        payment = msg.value;
        state = State.CREATED;
    }
    
    //////////////////////////////
    //// Requester Functions ////
    ////////////////////////////
    /**
     * Called by ride requester before an offer is ACCEPTED to cancel the 
     * request and refund all ether OR when the request has been REFUNDED by
     * the driver.
     */
    function cancelRequest() public requesterAccess {
        require(state == State.CREATED || state == State.REFUNDED);
        selfdestruct(requester);
    }
    
    
    //////////////////////////////
    ///// Driver Functions //////
    ////////////////////////////
    
    function createDriveOffer(int _curLatitude, uint _curLatitudeDecimal, 
                              int _curLongitude, uint _curLongitudeDecimal) 
                              public {
        require(driverOffers.length < MAX_OFFERS && !isDriver(msg.sender));
        
        Coordinate memory curLocation = Coordinate({
            latitude: _curLatitude,
            latitudeDecimal: _curLatitudeDecimal,
            longitude: _curLongitude,
            longitudeDecimal: _curLongitudeDecimal
        });
        
        DriverOffer memory newOffer = DriverOffer({
            driverAddress: msg.sender,
            location: curLocation
        });
        driverOffers.push(newOffer);
    }
    
    /**
     * Called by a driver who has made an offer that has yet to be STARTED
     * removes offer from offer list.
     */
    function cancelDriveOffer() public {
        require(state == State.CREATED);
        uint indexOfOffer = findDriveOffer(msg.sender);
        if (indexOfOffer != NOT_AN_OFFER) {
            removeDriveOffer(indexOfOffer);
        }
    }
    
    /**
     * Called by the driver when he is unable to fufill the contract.
     * Refunds the requester.
     */
    function refundRequest() public driverAccess {
        require(state == State.STARTED);
        state = State.REFUNDED;
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
    
    
    function findDriveOffer(address _driverAddress) private view returns(uint) {
        for (uint i; i < driverOffers.length; i++) {
            if (driverOffers[i].driverAddress == _driverAddress) {
                return i;
            }
        }
        return NOT_AN_OFFER;
    }
    
    function removeDriveOffer(uint index) private returns(DriverOffer[]) {
        if (index >= driverOffers.length) return;
        for (uint i = index; i<driverOffers.length-1; i++){
            driverOffers[i] = driverOffers[i+1];
        }
        driverOffers.length--;
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