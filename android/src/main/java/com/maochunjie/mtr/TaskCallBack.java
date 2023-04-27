package com.maochunjie.mtr;

public interface TaskCallBack {
    void onUpdated(String log);

    void onFinish(String log);

    void onFailed(Exception e);
}
