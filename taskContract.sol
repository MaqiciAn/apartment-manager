//// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.4;

contract Manager{
    address ApartmentManager; //apartman yonetici
    //Apartman yoneticisi contrat calistirildiginda calisitran adres aprtman yoneticisi oluyor.
    constructor() {
        ApartmentManager = msg.sender;
    }
    //Sadece apartman yoneticisinin degisiklik yapabilmesi icin gerekli bir modifier.
    modifier OnlyOwner(){
        require(msg.sender == ApartmentManager, "You are not manager.");
        _;
    }
    //Apartman yoneticisi degistigi zaman yeni aprtman yoneticisinin belirlendigi fonksiyon
    //Herkes degistiremeyecegi icin sadece apartman yoneticisi yoneticiligi verebiliyor.
    function setManager(address _Manager) external OnlyOwner{
        require(_Manager != address(0), "Invalid address"); 
        ApartmentManager = _Manager;
    }
    //Apartman yoneticisinin adresini veren fonksiyon
    function getManager() external view returns(address){
        return ApartmentManager;
    }
}
//Apartman sakinlerinin tanimlandigi ve onların yapabilecegi fonksiyonlara sahip kontrat
//Apartman sakinlerini eklerken sadece yonetici ekleyebilmesi icin manager fonksiyonundan inheritance alıyor
contract ApartmentResidents is Manager{

    struct Resident { //apartman sakinlerinin sahip oldugu ozellikler ve tipleri.
        uint8 doorNumber;
        string Name;
        string lastName;
        uint32 dues;
        uint debt;
        bool paid;
    }
    //Apartman sakinlerinin adrese gore ozelliklerini tutan mapping.
    mapping(address => Resident) Residents;
    //Bir apartmanda 8 kisi oldugu varsayarak yaptıgım apartman sakinlerinin adreslerini tutan bir array.
    address[8] public ResidentInfos;
    //Apartman yoneticisinin apartmana yeni gelen evsahiplerini ekledigi fonksiyon.
    //Bu fonksiyon oturanın adresini, kapı numarası,ismi,soyismi ve onun aidat ucretini set eden fonksiyon.
    //Sadece yonetici apartmana yeni gelen birisini ekleyebilmesi icin manager.onlyOwner modifierını burada kullanıyoruz.
    function setResident(address _address, uint8 _doorNumber, string memory _name, string memory _lastName, uint32 _dues) external Manager.OnlyOwner{
        //Gelen degerleri structa yazmak icin oturanın adresini alan structan bir variable olusturuyoruz.
        Resident storage resident = Residents[_address];
        //Gelen verileri structa ekliyrouz.
        resident.doorNumber = _doorNumber;
        resident.Name = _name;
        resident.lastName = _lastName;
        resident.dues = _dues;
        resident.debt = _dues;
        resident.paid = false;

        //oturacagı evin kapı numarasına gore diziye ekliyoruz.
        ResidentInfos[_doorNumber-1] = _address;
    }
    //Eger apartmandan ayrılan biri olursa burada siliyoruz.
    function delResident(uint8 _doorNumber) external Manager.OnlyOwner{
        delete ResidentInfos[_doorNumber-1];
    }
    //Apartmanda oturan insanların adreslerine bakabilecegimiz bir fonksiyon.
    function getResidentAddress() view public returns(address[8] memory){
        return ResidentInfos;
    }
    //Adresi verilen apartman sakininin bilgilerini almamıza yarayan fonksiyon.
    function getResidentinfo(address adres) view public returns(uint8,string memory,string memory,uint32,uint,bool){
        return (Residents[adres].doorNumber,
                Residents[adres].Name,
                Residents[adres].lastName,
                Residents[adres].dues,
                Residents[adres].debt,
                Residents[adres].paid);
    }
    //Sadece yoneticinin calistirabilecegi bir sonraki aya gecmek icin nasıl calistigini gostermek icin yazdıgım fonksiyon.
    function nextMounth() public Manager.OnlyOwner{
        for(uint i=0;i<ResidentInfos.length;i++){
            if(Residents[ResidentInfos[i]].paid){
                Residents[ResidentInfos[i]].paid=false;
                Residents[ResidentInfos[i]].debt += Residents[ResidentInfos[i]].dues;
            }
            else{
                Residents[ResidentInfos[i]].debt += Residents[ResidentInfos[i]].dues;
            }
        }
    }
    //Aidatını odeyecek apartman sakininin odemesini kontrol edildigi fonksiyon.
    //cuzdan adresini ve verdigi ucreti alarak islem yapıyor.
    function debtLog(address _adres,uint _value) public{
        //apartman sakinini kontrol etmek icin kontrol degiskeni
        bool member=false;
        //Apartman sakiniyse kimin odedigini tutan degisken.
        uint memberNumber;
        //Aidat odeyen kisinin apartman uyesimi kontrol edildigi dongu.
        for(uint i=0;i<ResidentInfos.length;i++){
            if(ResidentInfos[i] == _adres){
                member=true;
                memberNumber=i;
                break;
            }
        }
        //Eger apartman sakini degilse islem yaptırmıyoruz.
        require(member,"You are not apartment member");
        //Aylik aidati geciktirmis yada odememis kisinin gecmis aidatlarıyla beraber odeyip odemedigine gore
        //islem yapmamı saglıyor.
        if(Residents[ResidentInfos[memberNumber]].dues == _value || Residents[ResidentInfos[memberNumber]].debt == _value){
                Residents[ResidentInfos[memberNumber]].paid=true;
                Residents[ResidentInfos[memberNumber]].debt -= _value;
        }  
        //Aidat disi ucret girildiginde hata mesajı.
        else{
            revert("You can only 1 month or all dues pay");
        }      
    }
}
//Apartman sakinlerinin odeme yaptigi kontrat
contract payDebt{
    //Apartmantmanager ve apartmantresident kontrartlarini da kullanabilek icin variablelar.
    Manager manager;
    ApartmentResidents apartmentResi;
    //HAngi adresin kac para ucret yatirdigini tutan mapping.
    mapping(address => uint) Balance;
    //Ucret yatiran apartman sakininin islemini kayit altına alan event.
    event LogReceipt(uint indexed Date,uint indexed Amount,address indexed residentAdres);
    //Apartman yoneticisinin aidatlarını ne zaman ve hangi cuzdana aktardıgını tutan evet.
    event LogWithdraw(uint indexed Date, uint indexed Amount,address indexed withdrawAddress);
    //Diger kontratları kullanmamı saglayan constructer.
    constructor(address _managerContratAddres,address _apartmentResi){
        manager = Manager(_managerContratAddres);
        apartmentResi = ApartmentResidents(_apartmentResi);
    }
    //Apartman sakinlerinin aidatlarini odedigi fonksiyon
    function deposite() public payable {
        require ((Balance[msg.sender] + msg.value) >  Balance[msg.sender] && msg.sender!=address(0));
        //ApartmanResident kontratinda yazidigimiz apartman sakini mi degil mi ve ucretini kontrol ettigimiz
        //fonksiyonu burada aidati alirken kontrol ediyoruz.
        apartmentResi.debtLog(msg.sender,msg.value);
        //Gelen aidatı hersey uygunsa para adresine yaziyoruz. 
        Balance[msg.sender] += msg.value;
        //Apartman sakinlerinin aidatini yatirdiktan sonra kontrol edebilecegi log degeri.
        emit LogReceipt(block.timestamp,msg.value,msg.sender);
    }
    //Apartman yoneticisinin istedigi miktarda kontrattaki parayi cekebilecegi fonksiyon. 
    function withdraw(uint _withdrawAmount) public{
        //SAdece apartman yoneticisi cekebilsin diye kontrol.
        require(manager.getManager() == msg.sender, "You are not Manager");
        //kontrat adresini odeme yapabilmesi icin payable ayarliyorum.
        address payable withdrawAcc = payable(msg.sender);
        //Yoneticinin İstedigi degerde para cekmesini saglayan fonksiyon.
        (bool success, ) = withdrawAcc.call{value: _withdrawAmount}("");
        //Eger istedigi miktar kontrattaki miktardan coksa hata donduruyor.
        require(success, "Failed to send Ether");
        //Yoneticinin yaptigi para cekme islemini kaydeden event.
        emit LogWithdraw(block.timestamp,_withdrawAmount,msg.sender);
    }
}
