//+------------------------------------------------------------------+
//|                                               GridMaster Pro.mq5 |
//|                                           Copyright 2024, Sajid. |
//|                    https://www.mql5.com/en/users/sajidmahamud835 |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Sajid."
#property link "https://www.mql5.com/en/users/sajidmahamud835"
#property version "1.01"
#property strict

//--- Input parameters
input double LotSize = 0.1;
input int MaxOrders = 10;         // Maximum number of orders in the grid
input int ATRPeriod = 14;         // ATR period for dynamic grid adjustment
input double ATRMultiplier = 1.5; // Multiplier for ATR to calculate grid distance

//--- Global variables
double gridLevels[];
int ordersCount = 0;

//+------------------------------------------------------------------+
//| Error description function                                       |
//+------------------------------------------------------------------+
string ErrorDescription(int code)
{
    switch (code)
    {
    case 10004:
        return "Requote";
    case 10006:
        return "Request rejected";
    case 10007:
        return "Request canceled by trader";
    case 10008:
        return "Order placed";
    case 10009:
        return "Request completed";
    case 10010:
        return "Only part of the request was completed";
    case 10011:
        return "Request processing error";
    case 10012:
        return "Request canceled by timeout";
    case 10013:
        return "Invalid request";
    case 10014:
        return "Invalid volume in the request";
    case 10015:
        return "Invalid price in the request";
    case 10016:
        return "Invalid stops in the request";
    case 10017:
        return "Trade is disabled";
    case 10018:
        return "Market is closed";
    case 10019:
        return "There is not enough money to complete the request";
    case 10020:
        return "Prices changed";
    case 10021:
        return "There are no quotes to process the request";
    case 10022:
        return "Invalid order expiration date in the request";
    case 10023:
        return "Order state changed";
    case 10024:
        return "Too frequent requests";
    case 10025:
        return "No changes in request";
    case 10026:
        return "Autotrading disabled by server";
    case 10027:
        return "Autotrading disabled by client terminal";
    case 10028:
        return "Request locked for processing";
    case 10029:
        return "Order or position frozen";
    case 10030:
        return "Invalid order filling type";
    case 10031:
        return "No connection with the trade server";
    case 10032:
        return "Operation is allowed only for live accounts";
    case 10033:
        return "The number of pending orders has reached the limit";
    case 10034:
        return "The volume of orders and positions for the symbol has reached the limit";
    case 10035:
        return "Incorrect or prohibited order type";
    case 10036:
        return "Position with the specified POSITION_IDENTIFIER has already been closed";
    case 10038:
        return "A close volume exceeds the current position volume";
    case 10039:
        return "A close order already exists for a specified position";
    case 10040:
        return "The number of open positions simultaneously present on an account can be limited by the server settings";
    case 10041:
        return "The pending order activation request is rejected, the order is canceled";
    case 10042:
        return "The request is rejected, because the 'Only long positions are allowed' rule is set for the symbol";
    case 10043:
        return "The request is rejected, because the 'Only short positions are allowed' rule is set for the symbol";
    case 10044:
        return "The request is rejected, because the 'Only position closing is allowed' rule is set for the symbol";
    case 10045:
        return "The request is rejected, because 'Position closing is allowed only by FIFO rule' flag is set for the trading account";
    case 10046:
        return "The request is rejected, because the 'Opposite positions on a single symbol are disabled' rule is set for the trading account";
    default:
        return "Unknown error";
    }
}

//+------------------------------------------------------------------+
//| Initialization function                                          |
//+------------------------------------------------------------------+
int OnInit()
{
    //--- Initialize grid levels array size
    ArrayResize(gridLevels, MaxOrders);
    return (INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Deinitialization function                                        |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    //--- Cleanup code if needed
}

//+------------------------------------------------------------------+
//| Function to calculate dynamic grid distance                      |
//+------------------------------------------------------------------+
double CalculateDynamicGridDistance()
{
    //--- Correct iATR usage
    double atrValue = iATR(_Symbol, PERIOD_CURRENT, ATRPeriod);
    return atrValue * ATRMultiplier;
}

//+------------------------------------------------------------------+
//| Tick function                                                    |
//+------------------------------------------------------------------+
void OnTick()
{
    double lastPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double gridDistance = CalculateDynamicGridDistance();

    //--- Place the first order
    if (ordersCount == 0)
    {
        gridLevels[0] = lastPrice;
        if (OpenOrder(ORDER_TYPE_BUY, LotSize, lastPrice, 0, 0))
        {
            ordersCount++;
        }
    }

    //--- Place grid orders
    for (int i = 0; i < ordersCount && i < MaxOrders; i++)
    {
        if (lastPrice > gridLevels[i] + gridDistance * _Point)
        {
            gridLevels[i + 1] = lastPrice;
            if (OpenOrder(ORDER_TYPE_BUY, LotSize, lastPrice, 0, 0))
            {
                ordersCount++;
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Function to open an order                                        |
//+------------------------------------------------------------------+
bool OpenOrder(ENUM_ORDER_TYPE orderType, double lotSize, double price, double sl, double tp)
{
    MqlTradeRequest request;
    MqlTradeResult result;
    ZeroMemory(request);
    ZeroMemory(result);

    //--- Fill the request structure
    request.action = TRADE_ACTION_DEAL;
    request.symbol = _Symbol;
    request.volume = lotSize;
    request.type = orderType;
    request.price = price;
    request.sl = sl;
    request.tp = tp;
    request.deviation = 3;
    request.magic = 0;
    request.comment = "Grid Order";
    request.type_filling = ORDER_FILLING_IOC;

    //--- Retry logic
    const int maxRetries = 5;
    int retries = 0;

    while (retries < maxRetries)
    {
        if (!OrderSend(request, result))
        {
            if (result.retcode == 10004) // Trade server busy
            {
                retries++;
                Print("OrderSend failed (trade server busy), retrying... Attempt ", retries);
                Sleep(1000); // Wait for 1 second before retrying
            }
            else
            {
                Print("OrderSend failed: ", result.retcode, ". Reason: ", ErrorDescription(result.retcode));
                return false;
            }
        }
        else
        {
            Print("Order placed successfully: ", result.order);
            return true;
        }
    }

    Print("OrderSend failed after maximum retries");
    return false;
}

//+------------------------------------------------------------------+
