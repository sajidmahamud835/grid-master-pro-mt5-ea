# GridMaster Pro

GridMaster Pro is a MetaTrader 5 Expert Advisor (EA) that implements a grid trading strategy. It automatically opens buy orders at regular price intervals and manages them to maximize profits.

## Features

- **Grid Trading**: Automatically opens buy orders at specified intervals (grid levels).
- **Retry Mechanism**: Handles server busy errors by retrying the order submission.
- **Customizable Parameters**: Lot size, grid distance, and maximum orders can be configured.

## Installation

1. Download the `GridMasterPro.mq5` file from this repository.
2. Place the file in the `Experts` directory of your MetaTrader 5 installation.
3. Restart MetaTrader 5 or refresh the Expert Advisors section.
4. Attach the EA to a chart, configure the input parameters, and start trading.

## Input Parameters

- **LotSize**: The size of each order.
- **GridDistance**: Distance in points between grid levels.
- **MaxOrders**: Maximum number of orders in the grid.

## Usage

1. Attach the EA to a chart with sufficient historical data.
2. Set the desired input parameters.
3. Enable "AutoTrading" in MetaTrader 5.
4. Monitor the EA's performance and adjust settings as needed.

## Example

```mql5
input double LotSize = 0.1;
input double GridDistance = 50; // Distance between orders in points
input int MaxOrders = 10; // Maximum number of orders in the grid
```

## Contribution

Contributions are welcome! Please see the [Contribution Guide](CONTRIBUTING.md) for details on how to get involved.

## Disclaimer and Risk Warnings

Trading any financial market involves risk. All forms of trading carry a high level of risk, so you should only speculate with money you can afford to lose. You can lose more than your initial deposit and stake. Please ensure your chosen method matches your investment objectives, familiarize yourself with the risks involved, and if necessary, seek independent advice.

### NFA and CFTC Required Disclaimers

Trading in the Foreign Exchange market, Futures Market, Options, or the Stock Market is a challenging opportunity where above-average returns are available for educated and experienced investors who are willing to take above-average risks. However, before deciding to participate in Foreign Exchange (FX) trading, or in Trading Futures, Options, or stocks, you should carefully consider your investment objectives, level of experience, and risk appetite.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Author

[Sajid Mahamud](https://www.mql5.com/en/users/sajidmahamud835)