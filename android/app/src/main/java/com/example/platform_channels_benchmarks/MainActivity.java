package com.example.platform_channels_benchmarks;

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

    @Override
    public void configureFlutterEngine(FlutterEngine flutterEngine) {
        BasicMessageChannel<Object> reset = new BasicMessageChannel<>(flutterEngine.getDartExecutor(), "dev.flutter.echo.reset", StandardMessageCodec.INSTANCE);
        reset.setMessageHandler((message, reply) -> {
            byteBufferCache = null;
        });

        BasicMessageChannel<Object> basicStandard = new BasicMessageChannel<>(flutterEngine.getDartExecutor(), "dev.flutter.echo.basic.standard", StandardMessageCodec.INSTANCE);
        basicStandard.setMessageHandler((message, reply) -> reply.reply(message));

        BasicMessageChannel<ByteBuffer> basicBinary = new BasicMessageChannel<>(flutterEngine.getDartExecutor(), "dev.flutter.echo.basic.binary", BinaryCodec.INSTANCE_DIRECT);
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
            StandardMessageCodec.INSTANCE,
            flutterEngine.getDartExecutor().makeBackgroundTaskQueue()
        );
        backgroundStandard.setMessageHandler((message, reply) -> reply.reply(message));

        super.configureFlutterEngine(flutterEngine);
    }
}

