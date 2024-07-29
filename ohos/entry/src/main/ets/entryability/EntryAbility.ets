/*
* Copyright (c) 2023 Hunan OpenValley Digital Industry Development Co., Ltd.
* Licensed under the Apache License, Version 2.0 (the "License");
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at
*
*     http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
*/

import { common } from '@kit.AbilityKit';
import { taskpool } from '@kit.ArkTS';
import {
  Any,
  ApplicationInfoLoader,
  BackgroundMethodChannel,
  BackgroundBasicMessageChannel,
  BasicMessageChannel,
  BinaryCodec,
  FlutterAbility,
  FlutterEngine,
  MethodCall,
  MethodResult,
  SendableMethodCallHandler,
  SendableMessageHandler,
  StandardMessageCodec,
  SendableStandardMessageCodec,
  TaskPriority,
  TaskQueueOptions,
  SendableStandardMethodCodec
} from '@ohos/flutter_ohos';
import { Reply } from '@ohos/flutter_ohos/src/main/ets/plugin/common/BasicMessageChannel';
import { GeneratedPluginRegistrant } from '../plugins/GeneratedPluginRegistrant';

@Sendable
export class CustomStandardMessageCodec extends SendableStandardMessageCodec {
  static INSTANCE: CustomStandardMessageCodec = new CustomStandardMessageCodec();

  private constructor() {
    super();
  }

  encodeMessage(message: Any): ArrayBuffer {
    console.time('encodeMessage');
    let buffer = super.encodeMessage(message)
    console.timeLog('encodeMessage', `ByteBuffer: ${buffer.byteLength}`);
    console.timeEnd('encodeMessage');
    return buffer
  }

  decodeMessage(message: ArrayBuffer | null): Any {
    return super.decodeMessage(message)
  }
}

export default class EntryAbility extends FlutterAbility {
  private methodChannel: BackgroundMethodChannel | null = null;
  private reset: BasicMessageChannel<Object> | null = null;
  private basicStandard: BasicMessageChannel<Object> | null = null;
  private basicBinary: BasicMessageChannel<Object> | null = null;
  private backgroundStandard: BackgroundBasicMessageChannel<Object> | null = null;

  configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    GeneratedPluginRegistrant.registerWith(flutterEngine)

    let applicationInfo = ApplicationInfoLoader.load(this.context);
    console.log('xlog, isDebugMode = ' + applicationInfo.isDebugMode);

    @Sendable
    class PlatformStringCallback implements SendableMethodCallHandler {
      onMethodCall(call: MethodCall, result: MethodResult, ...args: Object[]): void {
        console.log(`xlog, #onMethodCall ~~, ${args}, length=${args.length}`);
        let context = args[0] as common.Context;
        let txt = args[1] as string;
        console.log(`xlog, #onMethodCall, txt=${txt}, context=${context}`);
        let applicationInfo = ApplicationInfoLoader.load(context);
        let appContext = context.getApplicationContext();
        let path: string = appContext.databaseDir;
        console.log('xlog, in background: isDebugMode = ' + applicationInfo.isDebugMode + ", text: " + txt + ", " + path);

        if (call.method == "getPlatformString") {
          result.success("Hi, there! I'm from ArkUI ^_^ ")
        } else {
          result.notImplemented()
        }
      }
    }

    let option: TaskQueueOptions = new TaskQueueOptions()
                                      .setIsSerial(true)
                                      .setSingleThreadMode(true)
                                      .setPriority(TaskPriority.HIGH);
    const taskQueue1 = flutterEngine.getDartExecutor().makeBackgroundTaskQueue(option);
    this.methodChannel = new BackgroundMethodChannel(
      flutterEngine.getDartExecutor(),
      "test/get_platform_name",
      SendableStandardMethodCodec.INSTANCE,
      taskQueue1,
      this.context,
      'another params'
    );
    this.methodChannel.setMethodCallHandler(new PlatformStringCallback());

    this.reset = new BasicMessageChannel<Object>(
      flutterEngine.getDartExecutor(),
      "dev.flutter.echo.reset",
      StandardMessageCodec.INSTANCE
    );
    this.reset.setMessageHandler({
      onMessage: (_, __) => {
      }
    })

    this.basicStandard = new BasicMessageChannel<Object>(
      flutterEngine.getDartExecutor(),
      "dev.flutter.echo.basic.standard",
      StandardMessageCodec.INSTANCE
    );
    this.basicStandard.setMessageHandler({
      onMessage: (message, reply) => {
        console.log('xlog, basicStandard ~~')
        reply.reply(message);
      }
    })

    this.basicBinary = new BasicMessageChannel<Object>(
        flutterEngine.getDartExecutor(),
        "dev.flutter.echo.basic.binary",
        BinaryCodec.INSTANCE_DIRECT
    );

    this.basicBinary.setMessageHandler({
      onMessage: (message, reply) => {
        reply.reply(message);
      }
    })

    this.backgroundStandard = new BackgroundBasicMessageChannel<Object>(
        flutterEngine.getDartExecutor(),
        "dev.flutter.echo.background.standard",
        CustomStandardMessageCodec.INSTANCE
    );

    @Sendable
    class ArrayBufferMessageHandler implements SendableMessageHandler<Object> {
      onMessage(message: Object, reply: Reply<Object>): void {
        console.log('xlog, ArrayBufferMessageHandler#onMessage is called in the background')
        reply.reply(message);
      }
    }
    this.backgroundStandard.setMessageHandler(new ArrayBufferMessageHandler)
  }
}
