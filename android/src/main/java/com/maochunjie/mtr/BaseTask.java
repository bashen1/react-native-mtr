package com.maochunjie.mtr;


public abstract class BaseTask {
    String url;
    String tag;
    TaskCallBack callBack;

    public BaseTask(String url, TaskCallBack callBack) {
        this.url = url;
        this.callBack = callBack;
    }

    public void doTask() {
        tag = System.currentTimeMillis() + "";
        // TraceTask运行于主线程
        if (this instanceof TraceTask) {
            getExecRunnable().run();
        } else {
            new Thread(getExecRunnable()).start();
        }
    }

    public void stop(){
        new Thread(getExecRunnable()).stop();
    }

//    public class updateResultRunnable implements Runnable {
//        String resultString;
//
//        public updateResultRunnable(String resultString) {
//            this.resultString = resultString;
//        }
//
//        @Override
//        public void run() {
//            /*if (resultTextView != null && resultTextView.getTag().equals(tag)) {
//                resultTextView.append(resultString);
//                resultTextView.requestFocus();
//            }*/
//            if (callBack != null) {
//                callBack.onUpdated(resultString);
//            }
//        }
//    }

    public abstract Runnable getExecRunnable();
}
