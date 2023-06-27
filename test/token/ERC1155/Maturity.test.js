/* eslint-disable no-undef */
const { time } = require('@nomicfoundation/hardhat-network-helpers');
const { expect, use } = require('chai');
const { solidity } = require('ethereum-waffle');
use(solidity);

const UTR = require('@derivable/utr/build/UniversalTokenRouter.json');
const bn = ethers.BigNumber.from;

contract('Maturity', function () {

    const initialURI = 'https://token-cdn-domain/{id}.json';

    beforeEach(async function () {
        const ERC1155Mock = await ethers.getContractFactory('$ERC1155Maturity');
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
                    ).to.be.revertedWith('Maturity: zb overflow');
                    await expect(
                        this.token.$_mint(this.accB.address, tokenId, uintMaxDiv2, lockTime, data)
                    ).to.be.revertedWith('Maturity: b overflow');
                    await expect(
                        this.token.$_mint(this.accB.address, tokenId, uintMaxDiv2, lockTime, data)
                    ).to.be.revertedWith('Maturity: b overflow');
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
                    ).to.be.revertedWith('Maturity: zb overflow');
                });
            
            it("Maturity overflow must be revert", async function () {
                const MAXUINT32 = 4294967296
                await expect(
                    this.token.$_mint(this.accA.address, tokenId, uint224MaxDiv2, MAXUINT32, data)
                ).to.be.revertedWith('Maturity: t overflow');
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

        describe('safeTransferFrom partly fungible', function () {
            it('Transfer to an empty account with same lock time', async function () {
                await this.token.connect(this.accA).safeTransferFrom(
                    this.accA.address,
                    this.accB.address,
                    tokenId,
                    mintAmount.div(2),
                    data
                )
                expect(await this.token.maturityOf(this.accA.address, tokenId))
                .to.be.equal(await this.token.maturityOf(this.accB.address, tokenId))
            });
            it('Merge two position will result in a position with a later maturity time', async function () {
                const curTime = await time.latest();
                await this.utr.exec([], [
                    {
                        inputs: [],
                        code: this.tokenAddress,
                        data: (await this.token.populateTransaction.$_mint(
                            this.accB.address, tokenId, mintAmount.mul(2), bn(30).add(curTime), data
                        )).data,
                    },
                    {
                        inputs: [],
                        code: this.tokenAddress,
                        data: (await this.token.populateTransaction.$_mint(
                            this.accB.address, tokenId, mintAmount, bn(10).add(curTime), data
                        )).data,
                    }
                ]);
                expect(await this.token.maturityOf(this.accB.address, tokenId)).to.be.equal(bn(30).add(curTime))
            });
            it("A maturing position cannot be transferred or merged into a more matured position", async function () {
                const curTime = bn(await time.latest())
                await this.token.$_mint(this.accB.address, tokenId, mintAmount, curTime.add(100), data);

                await expect(this.token.connect(this.accB).safeTransferFrom(this.accB.address, this.accA.address, tokenId, mintAmount, data))
                .to.be.revertedWith('Maturity: locktime order')

                await expect(this.token.$_mint(this.accB.address, tokenId, mintAmount, curTime.add(1000), data))
                .to.be.revertedWith('Maturity: locktime order')
            });
        });
    })
});