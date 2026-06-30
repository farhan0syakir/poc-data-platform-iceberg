/*
 * Licensed to the Apache Software Foundation (ASF) under one
 * or more contributor license agreements.  See the NOTICE file
 * distributed with this work for additional information
 * regarding copyright ownership.  The ASF licenses this file
 * to you under the Apache License, Version 2.0 (the
 * "License"); you may not use this file except in compliance
 * with the License.  You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package com.example;

import org.apache.flink.api.common.eventtime.WatermarkStrategy;
import org.apache.flink.api.common.functions.MapFunction;
import org.apache.flink.api.common.serialization.SimpleStringSchema;
import org.apache.flink.connector.kafka.sink.KafkaRecordSerializationSchema;
import org.apache.flink.connector.kafka.sink.KafkaSink;
import org.apache.flink.connector.kafka.source.KafkaSource;
import org.apache.flink.connector.kafka.source.enumerator.initializer.OffsetsInitializer;
import org.apache.flink.streaming.api.datastream.DataStream;
import org.apache.flink.streaming.api.environment.StreamExecutionEnvironment;

/**
 * Consumes messages from the Kafka topic {@code landing}, applies a
 * transformation, and produces the result into the Kafka topic {@code target},
 * which is consumed by the sink job.
 */
public class DataGeneratorJob {

	public static void main(String[] args) throws Exception {
		final StreamExecutionEnvironment env = StreamExecutionEnvironment.getExecutionEnvironment();

		KafkaSource<String> source = KafkaSource.<String>builder()
			.setBootstrapServers("kafka:9092")
			.setTopics("landing")
			.setGroupId("stream-group")
			.setStartingOffsets(OffsetsInitializer.earliest())
			.setValueOnlyDeserializer(new SimpleStringSchema())
			.build();

		DataStream<String> stream = env.fromSource(source, WatermarkStrategy.noWatermarks(), "Kafka Landing Source");

		// Transform each message: uppercase it and tag with a processing timestamp.
		DataStream<String> transformed = stream.map(new MapFunction<String, String>() {
			@Override
			public String map(String value) {
				return "[processed@" + System.currentTimeMillis() + "] " + value.toUpperCase();
			}
		});

		KafkaSink<String> sink = KafkaSink.<String>builder()
			.setBootstrapServers("kafka:9092")
			.setRecordSerializer(KafkaRecordSerializationSchema.builder()
				.setTopic("target")
				.setValueSerializationSchema(new SimpleStringSchema())
				.build())
			.build();

		transformed.sinkTo(sink);

		env.execute("Flink Kafka Landing To Target Job");
	}
}


