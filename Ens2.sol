// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.0 <0.9.0;

contract Ens {
    struct DomainInfo {
        address owner;
        uint256 registrationTime;
        uint256 registrationDuration; // Duration in years
        uint256 price;
    }

    mapping(string => DomainInfo) private domains;

    address public owner;
    uint256 public registrationPricePerYear;
    uint256 public renewalCoefficient;
    bool public paused = false;

    // Объявление события для лога
    event DomainRegistered(string domain, address owner, uint256 price, uint256 duration);
    event DomainRenewed(string domain, uint256 additionalYears, uint256 price);
    event RegistrationPricePerYearChanged(uint256 newPrice);
    event RenewalCoefficientChanged(uint256 newCoefficient);
    event Paused();
    event Unpaused();

    // Проверка на owner
    modifier onlyOwner() {
        require(msg.sender == owner, "Only the contract owner can call this function");
        _;
    }

    // Проверка на наличие домена
    modifier domainNotRegistered(string memory domain) {
        require(
            domains[domain].owner == address(0) || block.timestamp > domains[domain].registrationTime + domains[domain].registrationDuration * 365 days,
            "Domain is already registered and not expired"
        );
        _;
    }

    // Проверка на паузу
    modifier whenNotPaused() {
        require(!paused, "Contract is paused");
        _;
    }

    // Конструктор для присвоения owner адреса того кто деплоит контракт
    constructor(uint256 _registrationPricePerYear, uint256 _renewalCoefficient) {
        owner = msg.sender;
        registrationPricePerYear = _registrationPricePerYear;
        renewalCoefficient = _renewalCoefficient;
    }

    // Регистрация домена
    function registerDomain(string memory _domain, uint256 _years) public payable domainNotRegistered(_domain) whenNotPaused {
        require(_years >= 1 && _years <= 10, "Registration period must be between 1 and 10 years");
        uint256 requiredPayment = registrationPricePerYear * _years;
        require(msg.value >= requiredPayment, "Insufficient registration fee");

        domains[_domain] = DomainInfo({
            owner: msg.sender,
            registrationTime: block.timestamp,
            registrationDuration: _years,
            price: msg.value
        });

        // Эмиссия события, для того чтобы записать событие в лог транзакции
        emit DomainRegistered(_domain, msg.sender, msg.value, _years);
    }

    // Получение адреса владельца по домену
    function getDomainOwner(string memory domain) public view returns (address) {
        return domains[domain].owner;
    }

    // Получение информации о домене
    function getDomainInfo(string memory domain) public view returns (address, uint256, uint256, uint256) {
        DomainInfo memory info = domains[domain];
        return (info.owner, info.registrationTime, info.registrationDuration, info.price);
    }

    // Продление домена
    function renewDomain(string memory domain, uint256 additionalYears) public payable whenNotPaused {
        require(additionalYears >= 1 && additionalYears <= 10, "Renewal period must be between 1 and 10 years");
        require(domains[domain].owner == msg.sender, "Only the domain owner can renew the domain");

        uint256 requiredPayment = registrationPricePerYear * additionalYears * renewalCoefficient;
        require(msg.value >= requiredPayment, "Insufficient renewal fee");

        domains[domain].registrationDuration += additionalYears;
        domains[domain].price += msg.value;

        // Эмиссия события для продления домена
        emit DomainRenewed(domain, additionalYears, msg.value);
    }

    // Установка цены за год регистрации
    function setRegistrationPricePerYear(uint256 _registrationPricePerYear) public onlyOwner {
        registrationPricePerYear = _registrationPricePerYear;
        emit RegistrationPricePerYearChanged(_registrationPricePerYear);
    }

    // Установка коэффициента продления
    function setRenewalCoefficient(uint256 _renewalCoefficient) public onlyOwner {
        renewalCoefficient = _renewalCoefficient;
        emit RenewalCoefficientChanged(_renewalCoefficient);
    }

    // Включение паузы
    function pause() public onlyOwner {
        paused = true;
        emit Paused();
    }

    // Отключение паузы
    function unpause() public onlyOwner {
        paused = false;
        emit Unpaused();
    }

    // Снятие средств с контракта
    function withdraw() public onlyOwner {
        payable(owner).transfer(address(this).balance);
    }

    fallback() external payable { }
    receive() external payable { }
}
