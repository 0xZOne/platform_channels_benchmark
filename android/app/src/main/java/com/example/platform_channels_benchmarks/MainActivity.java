package com.example.platform_channels_benchmarks;

import android.util.Log;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.BasicMessageChannel;
import io.flutter.plugin.common.BinaryCodec;
import io.flutter.plugin.common.StandardMessageCodec;

import java.nio.ByteBuffer;

public class MainActivity extends FlutterActivity {
    // We allow for the caching of a response in the binary channel case since
    // the reply requires a direct buffer, but the input is not a direct buffer.
    // We can't directly send the input back to the reply currently.
    private ByteBuffer byteBufferCache = null;

    private static class CustomStandardMessageCodec extends StandardMessageCodec {
        public static final CustomStandardMessageCodec INSTANCE = new CustomStandardMessageCodec();

        private CustomStandardMessageCodec() {}

        @Override
        public ByteBuffer encodeMessage(Object message) {
            long startTime = System.nanoTime();
            ByteBuffer buffer = super.encodeMessage(message);
            long endTime = System.nanoTime();
            long duration = (endTime - startTime) / 1_000;
            Log.e("xlog", "encodeMessage: " + duration + " µs. ByteBuffer: " + buffer.capacity());
            return buffer;
        }

        @Override
        public Object decodeMessage(ByteBuffer message) {
            return super.decodeMessage(message);
        }
    }

    @Override
    public void configureFlutterEngine(FlutterEngine flutterEngine) {

        BasicMessageChannel<Object> reset = new BasicMessageChannel<>(
                flutterEngine.getDartExecutor(),
                "dev.flutter.echo.reset",
                CustomStandardMessageCodec.INSTANCE);
        reset.setMessageHandler((message, reply) -> {
            byteBufferCache = null;
        });

        BasicMessageChannel<Object> basicStandard = new BasicMessageChannel<>(
                flutterEngine.getDartExecutor(),
                "dev.flutter.echo.basic.standard",
                CustomStandardMessageCodec.INSTANCE);
        basicStandard.setMessageHandler((message, reply) -> reply.reply(message));

        BasicMessageChannel<ByteBuffer> basicBinary = new BasicMessageChannel<>(
                flutterEngine.getDartExecutor(),
                "dev.flutter.echo.basic.binary",
                BinaryCodec.INSTANCE_DIRECT);
        basicBinary.setMessageHandler((message, reply) -> {
            if (byteBufferCache == null) {
                byteBufferCache = ByteBuffer.allocateDirect(message.capacity());
                byteBufferCache.put(message);
            }
            reply.reply(byteBufferCache);
        });

        BasicMessageChannel<Object> backgroundStandard = new BasicMessageChannel<>(
                flutterEngine.getDartExecutor(),
                "dev.flutter.echo.background.standard",
                CustomStandardMessageCodec.INSTANCE,
                flutterEngine.getDartExecutor().makeBackgroundTaskQueue()
        );
        backgroundStandard.setMessageHandler((message, reply) -> reply.reply(message));

        super.configureFlutterEngine(flutterEngine);
    }
}

