# Name of the project - Momento

Total supply - 1 Trillion

Liquidity - 60%

Marketing and development - 5%

Burn - 20%\*

Staking - 12%

Team - 3% (Locked for 6 months and vested over 18 months)

There will be a 12% tax on every transaction :

3% - Added to liquidity

4% - gets redistributed to holders

4% - Buy back and burn (Not after every sell. Every time this wallet accumulates 0.2 ETH, an automatic buyback and burn is initiated for that 0.2 ETH worth of tokens)

1% - goes to marketing and development.

- Regarding the burn of 20%, 10% gets burnt at launch itself. For the remaining 10%, every time the number of holders increases by 100% (From 100 holders onwards), 10% of the remaining tokens gets burnt until it reaches 0 making the token deflationary. (So basically, when the number of holders increases from 100 to 200, 10% of the remaining burn tokens get burned. When it goes from 200, to 400, 10% of the remaining portion gets burned and so on.)

We also want a cool off period of 15 seconds between a buy and sell order. This is in order to avoid being front run by bots.

I'll try to explain it with an example.

If someone comes and buys $100 worth of tokens and the tokens are valued at $1 each. so he's ideally supposed to get 100 tokens. But since we have a tax of 12%, he would end up getting 88 tokens.

Out of the remaining 12 tokens:

3 tokens worth needs to get added to liquidity - So here 1.5 tokens would be converted to ETH by the contract and the other 1.5 tokens would be paired along with this ETH and added to the liquidity pool (similar to how safemoon and all other projects do it). Its a swap and not a transfer so the gas fee for the swap would include all the functions of the smart contract including the buying/selling portion, liquidity portion, buyback portion, etc and this is paid by the buyer/seller.

4 tokens gets redistributed to the remaining holders - All in tokens itself. Earlier this was 2% in tokens and 2% in ETH but then after our last discussion, we removed this ETH portion and kept it entirely as 4% in tokens itself.

4 tokens is sent to the buyback contract and automatically swapped for ETH (Similar to how INARI does). Once this wallet accumulates 0.2 ETH, it automatically buys back from the market and burns it.

1 token gets sent to the marketing and development wallet.
