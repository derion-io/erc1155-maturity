/* eslint-disable no-undef */
const { time } = require('@nomicfoundation/hardhat-network-helpers');
const { expect, use } = require('chai');
const { solidity } = require('ethereum-waffle');
use(solidity);

const UTR = require('@derivable/utr/build/UniversalTokenRouter.json');
const bn = ethers.BigNumber.from;

contract('Timelock', function () {

    const initialURI = 'https://token-cdn-domain/{id}.json';

    beforeEach(async function () {
        const ERC1155Mock = await ethers.getContractFactory('$ERC1155');
        this.token = await ERC1155Mock.deploy(initialURI);
        this.tokenAddress = this.token.address;
        const [accountA, accountB, accountC] = await ethers.getSigners();
        this.accA = accountA;
        this.accB = accountB;
        this.accC = accountC;

        const UniversalRouter = new ethers.ContractFactory(UTR.abi, UTR.bytecode, accountA)
        this.utr = await UniversalRouter.deploy()
    });
    describe('Overflow balance', function () {
        const tokenId = bn(1990);
        const uint224MaxDiv2 = bn(2).pow(224).div(2);
        const uintMaxDiv2 = bn(2).pow(256).div(2);
        const lockTime = bn(0);
        const data = '0x12345678';

        describe('_mint', function () {
            it('mint uint224.max / 2 => success\n' +
                '\t  mint uint224.max / 2 => failed\n' +
                '\t  mint uint.max / 2 => failed\n' +
                '\t  mint uint.max / 2 => failed', async function () {
                    await this.token.$_mint(this.accB.address, tokenId, uint224MaxDiv2, lockTime, data)
                    await expect(
                        this.token.$_mint(this.accB.address, tokenId, uint224MaxDiv2, lockTime, data)
                    ).to.be.revertedWith('Timelock: uint224 overflow');
                    await expect(
                        this.token.$_mint(this.accB.address, tokenId, uintMaxDiv2, lockTime, data)
                    ).to.be.revertedWith('Timelock: uint224 overflow');
                    await expect(
                        this.token.$_mint(this.accB.address, tokenId, uintMaxDiv2, lockTime, data)
                    ).to.be.revertedWith('Timelock: uint224 overflow');
                });
            
            it('mint uint224.max / 2 => A success\n' +
                '\t  mint uint224.max / 2 => B success\n' +
                '\t  mint uint224.max / 2 => C success\n' +
                '\t  mint uint224.max / 2 => A failed', async function () {
                    await this.token.$_mint(this.accA.address, tokenId, uint224MaxDiv2, lockTime, data)
                    await this.token.$_mint(this.accB.address, tokenId, uint224MaxDiv2, lockTime, data)
                    await this.token.$_mint(this.accC.address, tokenId, uint224MaxDiv2, lockTime, data)
                    await expect(
                        this.token.$_mint(this.accB.address, tokenId, uint224MaxDiv2, lockTime, data)
                    ).to.be.revertedWith('Timelock: uint224 overflow');
                });
            
            it("Timelock overflow must be revert", async function () {
                const MAXUINT32 = 4294967296
                await expect(
                    this.token.$_mint(this.accA.address, tokenId, uint224MaxDiv2, MAXUINT32, data)
                ).to.be.revertedWith('Timelock: uint32 overflow');
            });
        });
    });

    describe('Lock time', function () {
        const tokenId = bn(1990);
        const mintAmount = bn(1000);
        const expiration = bn(30);
        const data = '0x12345678';

        beforeEach(async function () {
            const lockTime = expiration.add(await time.latest());
            await this.token.$_mint(this.accA.address, tokenId, mintAmount, lockTime, data);
        });

        describe('safeTransferFrom', function () {
            it('reverts when transfer token before expiration', async function () {
                await expect(this.token.connect(this.accA).safeTransferFrom(this.accA.address, this.accB.address, tokenId, mintAmount, data)).to.be.revertedWith('Timelock: unexpired'); 
            });
            it('transfer was successful', async function () {
                await time.increase(60);
                await this.token.connect(this.accA).safeTransferFrom(this.accA.address, this.accB.address, tokenId, mintAmount, data);
            });
            it('Re calculate lock time', async function () {
                const curTime = await time.latest();
                await this.utr.exec([], [
                    {
                        inputs: [],
                        code: this.tokenAddress,
                        data: (await this.token.populateTransaction.$_mint(
                            this.accB.address, tokenId, mintAmount, bn(10).add(curTime), data
                        )).data,
                    },
                    {
                        inputs: [],
                        code: this.tokenAddress,
                        data: (await this.token.populateTransaction.$_mint(
                            this.accB.address, tokenId, mintAmount.mul(2), bn(30).add(curTime), data
                        )).data,
                    },
                ]);
                const lockDuration = Math.ceil((1000 * 10 + 1000 * 2 * 30) / (1000 * 3));
                await time.setNextBlockTimestamp(curTime + lockDuration - 1);
                await expect(
                    this.token.connect(this.accB).safeTransferFrom(this.accB.address, this.accC.address, tokenId, mintAmount, data)
                ).to.be.revertedWith('Timelock: unexpired');
                await this.token.connect(this.accB).safeTransferFrom(this.accB.address, this.accC.address, tokenId, mintAmount, data);
            });
            it("Dilution exploit", async function () {
                await this.token.connect(this.accB).setApprovalForAll(this.utr.address, true);
                const curTime = await time.latest();
                await expect(this.utr.exec([], [
                    {
                        inputs: [],
                        code: this.tokenAddress,
                        data: (await this.token.populateTransaction.$_mint(
                            this.accB.address, tokenId, bn(100), bn(1000).add(curTime), data
                        )).data,
                    },
                    {
                        inputs: [],
                        code: this.tokenAddress,
                        data: (await this.token.populateTransaction.$_mint(
                            this.accB.address, tokenId, bn(1000000000), bn(0).add(curTime), data
                        )).data,
                    },
                    {
                        inputs: [],
                        code: this.tokenAddress,
                        data: (await this.token.populateTransaction.safeTransferFrom(
                            this.accB.address, this.accC.address, tokenId, bn(100), data
                        )).data,
                    }
                ], {
                    gasLimit: 3000000
                })).to.be.revertedWith('Timelock: unexpired');
            });
        });
    })
});