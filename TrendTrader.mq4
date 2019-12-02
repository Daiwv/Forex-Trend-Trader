//+------------------------------------------------------------------+
//|                                                      TrendBot.mq4|
//|                                                  Andrew Richards |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Andrew Richards"
#property link      ""
#property version   "1.00"
#property strict

//Data:
extern double  Lots        = 1.0;
extern double  TakeProfit  = 950;
extern double  StopLoss    = 60;
extern int     MA_Period   = 160;
extern double  Deviation   = 0.3;
extern int     ATR_Period  = 50;
extern int     ATR_Shift   = 2;
//extern bool    UseTrailingStop = false;
//extern int     TrailingStop = 60;
extern bool    isSizingOn = true;
extern double  Risk = 1;
int            Slippage = 3;

static int  buyTicket  = 0;
static int  sellTicket = 0;

int P = 10;
bool isYenPair = false;

bool openBuy;
bool openSell;
bool close;
bool select;
double movingAverage;
double envUpper;
double envLower;
double atr_current;
double atr_past;
static bool bullTrend;
double StopLevel;
double stopLossLevel;
double takeProfitLevel;
const int timeframe = Period();


//filter bad trades..ENVELOPES INSTEAD OF MA
//minimize global variables
//bug when risk is too high?? doesn't execute trades or give errors??... check market info MODE_MINLOT MODE_MAXLOT?

void OnInit() {
   setIsYenPair();
   //setTrend();
}

void OnTick()
 {
   //-------------------------------------------------------
   //-----------------Data Initilization--------------------
   //-------------------------------------------------------
   
   setStopLevel();
   setSizing();//Sizing Algo
   
   movingAverage = iMA(NULL, timeframe, MA_Period, 0, 0, 0, 0);
  
   envUpper = iEnvelopes(NULL, timeframe, MA_Period, 0, 0, 0, Deviation, MODE_UPPER, 0); 
   envLower = iEnvelopes(NULL, timeframe, MA_Period, 0, 0, 0, Deviation, MODE_LOWER, 0);
   
   atr_current = iATR(NULL, 0, ATR_Period, 0); // compare different averaging periods instead of shifts??
   atr_past = iATR(NULL, 0, ATR_Period, ATR_Shift);
   openBuy = false;
   openSell = false;
   
   //Print(Lots);
   //Print("Free Margin: $", AccountFreeMargin());
   //Print("Account Balance: $", AccountBalance());
   //Print(MarketInfo(NULL, MODE_MINLOT));
   //Print(MarketInfo(NULL, MODE_MAXLOT));
   //-------------------------------------------------------------
   
   checkOpenTicket();
   checkCloseBuy();
   checkCloseSell();
   checkOpenBuy();
   checkOpenSell();
 }
 
 //-----------------------------------
 //------------Methods----------------
 //-----------------------------------
 //checking for new bar
 bool newBuyBar() {
   static datetime New_Time = 0; // New_Time = 0 when New_Bar() is first called
   if(New_Time!=Time[0]){      // If New_Time is not the same as the time of the current bar's open, this is a new bar
      New_Time=Time[0];        // Assign New_Time as time of current bar's open
      return(true);
   }
   return(false);
}
 bool newSellBar() {
   static datetime New_Time2 = 0; // New_Time = 0 when New_Bar() is first called
   if(New_Time2!=Time[0]){      // If New_Time is not the same as the time of the current bar's open, this is a new bar
      New_Time2=Time[0];        // Assign New_Time as time of current bar's open
      return(true);
   }
   return(false);
}
//Sizing Algo
void setSizing(){
    if (isSizingOn == true) {
      Lots = Risk * 0.01 * AccountBalance() / (MarketInfo(Symbol(),MODE_LOTSIZE) * StopLoss * P * Point); // Sizing Algo based on account size
      if(isYenPair == true) {
         Lots = Lots * 100; // Adjust for Yen Pairs
      }
      Lots = NormalizeDouble(Lots, 2); // Round to 2 decimal place
   }
}
//initilizing trend bool on start up
void setTrend(){
   movingAverage = iMA(NULL, timeframe, MA_Period, 0, 0, 0, 1);
   if(Bid > movingAverage){
      bullTrend = true;
   }
   else{
      bullTrend = false;
   }
}

//set IsYenPair on start up
void setIsYenPair(){
   if(Digits == 3) { // Adjust for YenPair
      isYenPair = true; 
   }
}

void setStopLevel(){
   StopLevel = (MarketInfo(NULL, MODE_STOPLEVEL) + MarketInfo(NULL, MODE_SPREAD)) / P;  // Defining minimum StopLevel
   if (StopLoss < StopLevel){
      StopLoss = StopLevel;
   }
   if (TakeProfit < StopLevel){
      TakeProfit = StopLevel;
   }
}

//***Check if selecting ticket was successful && check if order is still open***
void checkOpenTicket(){
   select = OrderSelect(buyTicket, SELECT_BY_TICKET);
   if(select == true && OrderCloseTime() == 0)
   {
      openBuy = true;
      //Adjust Trailing Stop - move somewhere else? refactor this
      /*if(UseTrailingStop && (TrailingStop > 0) && 
        (Bid - OrderOpenPrice() > P * Point * TrailingStop) &&
        (OrderStopLoss() < Bid - P * Point * TrailingStop)) {                 
            buyTicket = OrderModify(buyTicket, OrderOpenPrice(), Bid - P * Point * TrailingStop, OrderTakeProfit(), 0, MediumSeaGreen);
      }*/
   }
   else if (select == false){
      Print("Error Selecting Buy Ticket. Error: ", GetLastError());
   }
   
   select = OrderSelect(sellTicket, SELECT_BY_TICKET);
   if(select == true && OrderCloseTime() == 0)
   {
      openSell = true;
      //Adjust Trailing stop - move this somewhere else? refactor this
      /*if(UseTrailingStop && (TrailingStop > 0) &&
        (OrderOpenPrice() - Ask > P * Point * TrailingStop) &&
        ((OrderStopLoss() > Ask + P * Point * TrailingStop) || (OrderStopLoss() == 0))) {                 
            sellTicket = OrderModify(sellTicket, OrderOpenPrice(), Ask + P * Point * TrailingStop, OrderTakeProfit(), 0, DarkOrange);
      }*/
   }
   else if (select == false){
      Print("Error Selecting Sell Ticket. Error: ", GetLastError());
   }
}


void checkCloseSell(){
   if(openSell == true){
      //if(Close[1] > movingAverage)
      if((Close[2] < envLower && Close[1] > envLower) || Close[1] > envUpper)
      {
         close = OrderClose(sellTicket, Lots, Ask, Slippage);
         if(close == false){
            Print("Failed Close Sell. Error: ", GetLastError());
         }
         else{
            openSell = false;
            Print("Sell Order Closed");
         }
      }
   }
}
void checkCloseBuy(){
   if(openBuy == true){
      //if(Close[1] < movingAverage)
      if((Close[2] > envUpper && Close[1] < envUpper) || Close[1] < envLower)
      {
         close = OrderClose(buyTicket, Lots, Bid, Slippage);
         if(close == false){
            Print("Failed Close Buy. Error: ", GetLastError());
         }
         else{
            openBuy = false;
            Print("Buy Order Closed");
         }
      }
   }
}
void checkOpenSell(){
   if(openSell == false)
   {
      if (AccountFreeMargin() < (1000 * Lots)) {
            Print("We have no money. Free Margin = ", AccountFreeMargin());
      }
      if(Close[2] > movingAverage && Close[1] < movingAverage)// && atr_current > atr_past)
      {
        if(newSellBar() == true){
           stopLossLevel = Ask + StopLoss*Point;
           takeProfitLevel = Ask - TakeProfit*Point;
           sellTicket = OrderSend(NULL, OP_SELL, Lots, Bid, Slippage, stopLossLevel, takeProfitLevel, "Set by "); //sell order if it is above
           //bullTrend = false;
           Print("Sell Order Opened");
           if(sellTicket < 0)
           {
              Print("Error Order Failed", GetLastError());
           }
        }
      }
   }
}
void checkOpenBuy(){
   if(openBuy == false)
   {
      if (AccountFreeMargin() < (1000 * Lots)) {
            Print("We have no money. Free Margin = ", AccountFreeMargin());
      }
      if(Close[2] < movingAverage && Close[1] > movingAverage)// && atr_current > atr_past)
      {
         if(newBuyBar() == true){
            stopLossLevel = Bid - StopLoss*Point;
            takeProfitLevel = Bid + TakeProfit*Point;
            buyTicket = OrderSend(NULL, OP_BUY, Lots, Ask, Slippage, stopLossLevel, takeProfitLevel, "Set by "); // buy order if it is below
            //bullTrend = true;
            Print("Buy Order Opened");
            if(buyTicket < 0)
            {
               Print("Error Buy Order Failed", GetLastError());
            }
         }
      }
   }
}


//+------------------------------------------------------------------+
