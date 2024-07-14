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

import {
  Any,
  ApplicationInfoLoader,
  BasicMessageChannel,
  BinaryCodec,
  ByteBuffer,
  FlutterAbility,
  FlutterEngine,
  SendableMessageHandler,
  StandardMessageCodec,
  SendableStandardMessageCodec,
  TaskQueueOptions
} from '@ohos/flutter_ohos';
import { Reply } from '@ohos/flutter_ohos/src/main/ets/plugin/common/BasicMessageChannel';
import { MessageHandler } from '@ohos/flutter_ohos/src/main/ets/plugin/common/BasicMessageChannel';
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
  private byteBufferCache: ByteBuffer | null = null;

  configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    GeneratedPluginRegistrant.registerWith(flutterEngine)

    let applicationInfo = ApplicationInfoLoader.load(this.context);
    console.log('xlog, isDebugMode = ' + applicationInfo.isDebugMode)

    const reset = new BasicMessageChannel<Object>(
      flutterEngine.getDartExecutor(),
      "dev.flutter.echo.reset",
      StandardMessageCodec.INSTANCE
    );
    reset.setMessageHandler({
      onMessage: (_, __) => {
        this.byteBufferCache = null;
      }
    })

    const basicStandard = new BasicMessageChannel<Object>(
      flutterEngine.getDartExecutor(),
      "dev.flutter.echo.basic.standard",
      StandardMessageCodec.INSTANCE
    );
    basicStandard.setMessageHandler({
      onMessage: (message, reply) => {
        console.log('xlog, basicStandard ~~')
        reply.reply(message);
      }
    })

    const basicBinary = new BasicMessageChannel<Object>(
        flutterEngine.getDartExecutor(),
        "dev.flutter.echo.basic.binary",
        BinaryCodec.INSTANCE_DIRECT
    );

    basicBinary.setMessageHandler({
      onMessage: (message, reply) => {
        reply.reply(message);
      }
    })

    const taskQueue = flutterEngine.getDartExecutor().makeBackgroundTaskQueue(new TaskQueueOptions());
    const backgroundStandard = new BasicMessageChannel<Object>(
        flutterEngine.getDartExecutor(),
        "dev.flutter.echo.background.standard",
        CustomStandardMessageCodec.INSTANCE,
        taskQueue
    );

    @Sendable
    class ArrayBufferMessageHandler implements SendableMessageHandler<Object> {
      onMessage(message: Object, reply: Reply<Object>): void {
        console.log('xlog, ArrayBufferMessageHandler#onMessage is called in the background')
        reply.reply(message);
      }
    }
    backgroundStandard.setMessageHandler(new ArrayBufferMessageHandler)
  }
}
