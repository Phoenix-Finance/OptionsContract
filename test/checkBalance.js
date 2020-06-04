var BN = require("bn.js");
module.exports =  class {
    constructor(accounts,oracle,token){

        this.oracle = oracle;
        this.token = token;
        this.balanceInfo = {};
        this.accounts = [];
        for (var i=0;i<accounts.length;i++){
            this.accounts.push(accounts[i]);
            this.balanceInfo[accounts[i]] = {checkValue:new BN(0)};
        }
    }
    addAccount(account){
        this.accounts.push(account);
        this.balanceInfo[account] = {checkValue:new BN(0)};
    }
    async beforeFunction(){
        if (!this.token){
            await this._EthBeforeFunction();
        }else{
            await this._TokenBeforeFunction();
        }

    }
    addAccountCheckValue(account,checkValue){
        if(!this.balanceInfo[account]){
            return;
        }
        if (BN.isBN(checkValue)){
            this.balanceInfo[account].checkValue = this.balanceInfo[account].checkValue.add(checkValue);
        }else{
            if(checkValue > 0){
                let newBn = new BN(checkValue.toString(16),16);
                this.balanceInfo[account].checkValue = this.balanceInfo[account].checkValue.add(newBn);
            }else{
                checkValue = -checkValue;
                let newBn = new BN(checkValue.toString(16),16);
                this.balanceInfo[account].checkValue = this.balanceInfo[account].checkValue.sub(newBn);
            }
    
        }
    }
    async setTx(tx){
        if (!this.token){
            await this._EthSetTx(tx);
        }else{
            await this._TokenSetTx(tx);
        }
    }
    async checkFunction(){
        if (!this.token){
            await this._EthCheckFunction();
        }else{
            await this._TokenCheckFunction();
        }

    }

    async _EthBeforeFunction(){
        for (var i=0;i<this.accounts.length;i++){
            this.balanceInfo[this.accounts[i]].beforeBalance = await this.oracle.getEthBalance(this.accounts[i]);
        }
    }
    async _TokenBeforeFunction(){
        for (var i=0;i<this.accounts.length;i++){
            this.balanceInfo[this.accounts[i]].beforeBalance = await this.token.balanceOf(this.accounts[i]);
        }
    }
    async _EthCheckFunction(){
        for (var i=0;i<this.accounts.length;i++){
            let account = this.accounts[i];
            this.balanceInfo[account].finalBalance = await this.oracle.getEthBalance(account);
            let subBal = this.balanceInfo[account].finalBalance.sub(this.balanceInfo[account].beforeBalance);
            let checkZero = subBal.sub(this.balanceInfo[account].checkValue).toNumber();
            assert.equal(checkZero,0,account + " balance check failed");
//            console.log("-----------------------1",checkZero);
        }
    }
    async _TokenCheckFunction(){
        for (var i=0;i<this.accounts.length;i++){
            let account = this.accounts[i];
            this.balanceInfo[account].finalBalance = await this.token.balanceOf(account);
            let subBal = this.balanceInfo[account].finalBalance.sub(this.balanceInfo[account].beforeBalance);
            let checkZero = subBal.sub(this.balanceInfo[account].checkValue).toNumber();
//            console.log("-----------------------2",checkZero);
            assert.equal(checkZero,0,this.token+ ": "+ account + " token balance check failed");
        }
    }

    async _EthSetTx(txHash){
        let tx = await web3.eth.getTransaction(txHash);
        let txReceipt = await web3.eth.getTransactionReceipt(txHash);
        let bnGas = new BN(-txReceipt.gasUsed);
        let bnPrice = new BN(tx.gasPrice);
        this.addAccountCheckValue(tx.from,bnPrice.mul(bnGas));
    }
    async _TokenSetTx(txHash){

    }
}
