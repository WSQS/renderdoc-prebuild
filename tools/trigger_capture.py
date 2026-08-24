import os
import time
import traceback

import renderdoc as rd


HOST = os.environ.get("RENDERDOC_TARGET_HOST", "127.0.0.1")
PORT = int(os.environ.get("RENDERDOC_TARGET_PORT", "38920"))
OUTPUT_PATH = os.environ["RENDERDOC_CAPTURE_OUTPUT"]
STATUS_PATH = os.environ["RENDERDOC_CAPTURE_STATUS"]
TIMEOUT_SECONDS = int(os.environ.get("RENDERDOC_CAPTURE_TIMEOUT", "90"))


def log(message):
	with open(STATUS_PATH, "a", encoding="utf-8") as status_file:
		status_file.write(message + "\n")
		status_file.flush()


def receive_until(target, predicate, description):
	deadline = time.monotonic() + TIMEOUT_SECONDS
	while time.monotonic() < deadline:
		message = target.ReceiveMessage(None)
		if message.type == rd.TargetControlMessageType.Disconnected:
			raise RuntimeError("Target control disconnected while waiting for " + description)
		if predicate(message):
			return message
		time.sleep(0.01)
	raise RuntimeError("Timed out waiting for " + description)


def main():
	output_dir = os.path.dirname(OUTPUT_PATH)
	if output_dir:
		os.makedirs(output_dir, exist_ok=True)

	log("Connecting to {}:{}".format(HOST, PORT))
	target = rd.CreateTargetControl(HOST, PORT, "linuxcluster-capture", True)
	if target is None:
		raise RuntimeError("Could not connect to the RenderDoc target")

	try:
		api_message = receive_until(
			target,
			lambda message: (
				message.type == rd.TargetControlMessageType.RegisterAPI
				and message.apiUse.presenting
				and message.apiUse.supported
			),
			"a supported presenting graphics API",
		)
		log("Connected to API: " + api_message.apiUse.name)

		target.TriggerCapture(1)
		log("Capture triggered")

		capture_message = receive_until(
			target,
			lambda message: message.type == rd.TargetControlMessageType.NewCapture,
			"a new capture",
		)
		capture_id = capture_message.newCapture.captureId
		log(
			"Captured frame {} to {}".format(
				capture_message.newCapture.frameNumber,
				capture_message.newCapture.path,
			)
		)

		target.CopyCapture(capture_id, OUTPUT_PATH)
		receive_until(
			target,
			lambda message: (
				message.type == rd.TargetControlMessageType.CaptureCopied
				and message.newCapture.captureId == capture_id
			),
			"the local capture copy",
		)
		log("Capture copied to " + OUTPUT_PATH)
	finally:
		target.Shutdown()


try:
	main()
except Exception:
	log(traceback.format_exc())
	os._exit(1)

os._exit(0)
