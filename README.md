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
