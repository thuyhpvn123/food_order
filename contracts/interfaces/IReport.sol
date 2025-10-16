// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import "./IRestaurant.sol";

interface IRestaurantReporting {
     function UpdateDailyStats(uint date, uint revenue, uint orders) external;
     function updateDishStartTime(string memory dishCode,uint createdAt) external ;
     function UpdateDishDailyData(
        string memory dishCode,
        uint date,
        uint revenue,
        uint orders
     ) external ;
     
}