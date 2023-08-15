// SPDX-License-Identifier: MIT
// from https://solidity-by-example.org/new-contract/
pragma solidity ^0.8.17;

import {Car} from './Car.sol';

contract CarFactory {
    Car[] public cars;

    function create(address _owner, string memory _model) public {
        Car car = new Car(_owner, _model);
        cars.push(car);
    }

    function createAndSendEther(address _owner, string memory _model) public payable {
        Car car = (new Car){value: msg.value}(_owner, _model);
        cars.push(car);
    }

    function create2(address _owner, string memory _model, bytes32 _salt) public {
        Car car = (new Car){salt: _salt}(_owner, _model);
        cars.push(car);
    }

    function create2AndSendEther(address _owner, string memory _model, bytes32 _salt) public payable {
        Car car = (new Car){value: msg.value, salt: _salt}(_owner, _model);
        cars.push(car);
    }

    function getCar(
        uint _index
    ) public view returns (address owner, string memory model, address carAddr, uint balance) {
        Car car = cars[_index];

        return (car.owner(), car.model(), car.carAddr(), address(car).balance);
    }
}
