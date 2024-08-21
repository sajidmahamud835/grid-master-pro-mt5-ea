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
        return "Trade server busy";
    case 10006:
        return "Unsupported by trade server";
    case 10007:
        return "Account disabled";
    case 10008:
        return "Invalid account";
    case 10009:
        return "Trade timeout";
    case 10010:
        return "Invalid price";
    case 10011:
        return "Invalid stops";
    case 10012:
        return "Invalid trade volume";
    case 10013:
        return "Market is closed";
    case 10014:
        return "Trade is prohibited";
    case 10015:
        return "Insufficient funds";
    case 10016:
        return "Price changed";
    case 10017:
        return "No quote";
    case 10018:
        return "Requote";
    case 10019:
        return "Order is locked";
    case 10020:
        return "Long positions only allowed";
    case 10021:
        return "Too many requests";
    case 10022:
        return "Trade modify denied";
    case 10023:
        return "Trade context busy";
    case 10024:
        return "Order rejected";
    case 10025:
        return "Trade is disabled";
    case 10026:
        return "Not enough money";
    case 10027:
        return "Too many pending orders";
    case 10028:
        return "No right for operation";
    case 10029:
        return "Operation timeout";
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
