//+------------------------------------------------------------------+
//|                                      Moving Average_Мodified.mq4 |
//|                      Copyright © 2013, MetaQuotes Software Corp. |
//|                                      Modified by BARS            |
//+------------------------------------------------------------------+
//截短亏损，让利润奔腾
#define MAGICMA  20160917
#define UP "UP"
#define DOWN "DOWN"
#define UP_CROSS "UP_CROSS"
#define DOWN_CROSS "DOWN_CROSS"
//-----------------------------------------
extern int     StopLoss           = 10;
extern int     InitingStopLoss    = 20;
extern int     StopStep           = 4;
extern int     MinProfit          = 5;

/*
PERIOD_M1
PERIOD_M5
PERIOD_M15
PERIOD_M30 30
PERIOD_H1 60
PERIOD_H4 240
PERIOD_D1 1440
PERIOD_W1 10080 
PERIOD_MN1 43200
*/
#define TIME_FRAME_ 1
#ifdef TIME_FRAME_
extern int   TimeFrame_Small =  PERIOD_M30;
extern int   TimeFrame_Big =  PERIOD_H4;
#else 
extern int   TimeFrame_Small = PERIOD_H4;
extern int   TimeFrame_Big = PERIOD_D1;
#endif 
extern double  DecreaseFactor     = 3;
extern int     MovingShift        = 1;
extern color   BuyColor           = clrCornflowerBlue;
extern color   SellColor          = clrSalmon;
//---
double SL=0,TP=0;
bool  bNoHandingStop = true;
int num = 0;
//-- Include modules --
#include <stderror.mqh>
#include <stdlib.mqh>
#include <CustomFunction.mqh>
string m_tradeSigal = "";
//+------------------------------------------------------------------+
int OnInit()
{
   //Print("StopLoss=", StopLoss, " TakeProfit=", TakeProfit, " MovingPeriod_Open=", MovingPeriod_Open, " MovingPeriod_Close=", MovingPeriod_Close);
   return(INIT_SUCCEEDED);
}                                                                
//+------------------------------------------------------------------+
void start()
{   
//--- If there are more than 100 bars in the chart and the trade flow is free
   bool res = IsTradeAllowed();
   if(Bars<100 || res==false)
      return;
   if(CheckNewBar() == false)
      return;
   string direct = GetCurrentDirect();
   m_tradeSigal = GetTradeSigal();
//--- If the calculated lot size is in line with the current deposit amount
   if(CalculateOpenedOrdersNum(Symbol())==0)
      CheckForOpen();   // start working
   else
      CheckForClose();  // otherwise, close positions
}
//+------------------------------------------------------------------+
//| Calculates the optimum lot size                                  |
//+------------------------------------------------------------------+

  
  string GetCurrentDirect()
  {
      string direct = UP;
      double mainValue = iStochastic(NULL,TimeFrame_Big,5,3,3,MODE_SMA,0,MODE_MAIN,MovingShift);
      double signalValue = iStochastic(NULL,TimeFrame_Big,5,3,3,MODE_SMA,0,MODE_SIGNAL,MovingShift);
      if(mainValue < signalValue)
         direct = DOWN;
      log_out(StringFormat("**********TimeFrame_Big----timeframe:%d, mainValue:%f signalValue:%f",TimeFrame_Big, mainValue, signalValue), 11);
      return direct;
  }
  string GetTradeSigal()  //获取交易信号
  {
      string direct = "";
      double preMainValue = iStochastic(NULL,TimeFrame_Small,5,3,3,MODE_SMA,0,MODE_MAIN,MovingShift+1); 
      double preSignalValue = iStochastic(NULL,TimeFrame_Small,5,3,3,MODE_SMA,0,MODE_SIGNAL,MovingShift+1);
      double mainValue = iStochastic(NULL,TimeFrame_Small,5,3,3,MODE_SMA,0,MODE_MAIN,MovingShift);
      double signalValue = iStochastic(NULL,TimeFrame_Small,5,3,3,MODE_SMA,0,MODE_SIGNAL,MovingShift);
      if(preMainValue <= preSignalValue && mainValue > signalValue)
         direct = UP_CROSS;
      else if(preMainValue >= preSignalValue && mainValue < signalValue)
         direct = DOWN_CROSS;
      //log_out(StringFormat("**********mainValue:%f signalValue:%f", mainValue, signalValue), 11);
      log_out(StringFormat("preMainValue:%f  preSignalValue:%f mainValue:%f signalValue:%f", preMainValue, preSignalValue, mainValue, signalValue));
      return direct;
  }
  
//+------------------------------------------------------------------+
//| Position opening function                                        |
//+------------------------------------------------------------------+
void CheckForOpen()
{
   double ma;
   int    res;
   //---- buy conditions
   if( m_tradeSigal == UP_CROSS ) //&& GetCurrentDirect() == UP
   {
         int ticket = OpenBuyOrder(Symbol(), LotsOptimized(), 5, MAGICMA,  "Buy Order");
         AddStopProflt(ticket, MarketInfo(Symbol(), MODE_BID)-InitingStopLoss*PipPoint(Symbol()), 0);
         log_out(StringFormat("%sUP_CROSS", "----"));
   }
   //---- sell conditions
   if( m_tradeSigal == DOWN_CROSS )//&& GetCurrentDirect() == DOWN
   {
         int ticket = OpenSellOrder(Symbol(), LotsOptimized(), 5, MAGICMA,  "Buy Order");
         AddStopProflt(ticket, MarketInfo(Symbol(), MODE_ASK)+InitingStopLoss*PipPoint(Symbol()), 0);
         log_out(StringFormat("%sDOWN_CROSS", "----"));
   }
   bNoHandingStop = true;
}
//+------------------------------------------------------------------+
//| Position closing function                                        |
//+------------------------------------------------------------------+
void CheckForClose()
{
   double ma;
   for(int i=0;i<OrdersTotal();i++)
   {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)==false) break;
      if(OrderMagicNumber()!=MAGICMA || OrderSymbol()!=Symbol()) continue;
      //---- check order type 
      if(OrderType()==OP_BUY)
      {
         if(m_tradeSigal == DOWN_CROSS)  //GetCurrentDirect() == DOWN || 
            OrderClose(OrderTicket(), OrderLots(), Bid, 5, BuyColor);
      }
      if(OrderType()==OP_SELL)
      {
          if( m_tradeSigal == UP_CROSS)  //GetCurrentDirect() == UP ||
             OrderClose(OrderTicket(),OrderLots(),Ask,5,SellColor); 
      }
   }
   CheckTrailingStop(Symbol(), StopLoss, MinProfit, MAGICMA);
}

void CheckTrailingStop(string argSymbol, int argTrailingStop, int argMinProfit,
   int argMagicNumber)
{
   for(int Counter = 0; Counter < OrdersTotal(); Counter++)
   {
      OrderSelect(Counter, SELECT_BY_POS);
      if(OrderSymbol() != argSymbol || OrderMagicNumber() != argMagicNumber ) continue;
      if(OrderType() == OP_BUY)
      {
         double MaxStopLoss = MarketInfo(argSymbol, MODE_BID) - (argTrailingStop*PipPoint(argSymbol));
         MaxStopLoss = NormalizeDouble(MaxStopLoss, MarketInfo(argSymbol, MODE_DIGITS));
         double CurrentStop = NormalizeDouble(OrderStopLoss(), MarketInfo(argSymbol, MODE_DIGITS));
         double PipsProfit = MarketInfo(argSymbol, MODE_BID) - OrderOpenPrice();
         double minProfit = argMinProfit*PipPoint(argSymbol);
         if(bNoHandingStop = true)
         {
            if(CurrentStop < MaxStopLoss && PipsProfit >= minProfit)
            {
               bool Trailed = OrderModify(OrderTicket(), OrderOpenPrice(), MaxStopLoss, OrderTakeProfit(), 0);
               bNoHandingStop = false;
               if(Trailed == false)
               {
                  Print("Error CheckTrailingStop \n");
               }
            }
         }
         else 
         {
            if(MaxStopLoss - CurrentStop > StopStep*PipPoint(argSymbol))
            {
               bool Trailed = OrderModify(OrderTicket(), OrderOpenPrice(), MaxStopLoss, OrderTakeProfit(), 0);
               if(Trailed == false)
               {
                  Print("Error CheckTrailingStop \n");
               }
            }
         }
      }
      else if(OrderType() == OP_SELL)
      {
         double MaxStopLoss = MarketInfo(argSymbol, MODE_ASK) + (argTrailingStop*PipPoint(argSymbol));
         MaxStopLoss = NormalizeDouble(MaxStopLoss, MarketInfo(argSymbol, MODE_DIGITS));
         double CurrentStop = NormalizeDouble(OrderStopLoss(), MarketInfo(argSymbol, MODE_DIGITS));
         double PipsProfit = OrderOpenPrice() - MarketInfo(argSymbol, MODE_ASK);
         double minProfit = argMinProfit*PipPoint(argSymbol);      
         if(bNoHandingStop = true)
         {
            if(CurrentStop > MaxStopLoss && PipsProfit >= minProfit)
            {
               bool Trailed = OrderModify(OrderTicket(), OrderOpenPrice(), MaxStopLoss, OrderTakeProfit(), 0);
               bNoHandingStop = false;
               if(Trailed == false)
               {
                  Print("Error CheckTrailingStop \n");
               }
            }
         }
         else 
         {
            if(CurrentStop - MaxStopLoss > StopStep*PipPoint(argSymbol))
            {
               bool Trailed = OrderModify(OrderTicket(), OrderOpenPrice(), MaxStopLoss, OrderTakeProfit(), 0);
               if(Trailed == false)
               {
                  Print("Error CheckTrailingStop \n");
               }
            }
         }
      }
   }
}
