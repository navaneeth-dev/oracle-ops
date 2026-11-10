# Signs S3 requests the way Ente's museum does: it hands out presigned URLs
# and the client (curl, standing in for the phone or browser) sends the bytes.
# Credentials, region, endpoint and CA bundle come from the AWS_* environment
# set by the s3helper wrapper in default.nix.
import base64
import hashlib
import json
import sys

import boto3
from botocore.config import Config

BUCKET = "ente"
s3 = boto3.client(
    "s3",
    config=Config(signature_version="s3v4", s3={"addressing_style": "path"}),
)
cmd, *args = sys.argv[1:]

if cmd == "presign-put":
    key, path, md5 = args[0], args[1], args[2] if len(args) > 2 else None
    if md5 is None:
        with open(path, "rb") as f:
            md5 = base64.b64encode(hashlib.md5(f.read()).digest()).decode()
    url = s3.generate_presigned_url(
        "put_object",
        Params={"Bucket": BUCKET, "Key": key, "ContentMD5": md5},
        ExpiresIn=600,
    )
    print(json.dumps({"url": url, "md5": md5}))
elif cmd == "presign-get":
    print(
        s3.generate_presigned_url(
            "get_object", Params={"Bucket": BUCKET, "Key": args[0]}, ExpiresIn=600
        )
    )
elif cmd == "mpu-create":
    print(s3.create_multipart_upload(Bucket=BUCKET, Key=args[0])["UploadId"])
elif cmd == "presign-part":
    key, upload_id, part = args
    print(
        s3.generate_presigned_url(
            "upload_part",
            Params={
                "Bucket": BUCKET,
                "Key": key,
                "UploadId": upload_id,
                "PartNumber": int(part),
            },
            ExpiresIn=600,
        )
    )
elif cmd == "mpu-complete":
    key, upload_id, *etags = args
    s3.complete_multipart_upload(
        Bucket=BUCKET,
        Key=key,
        UploadId=upload_id,
        MultipartUpload={
            "Parts": [{"PartNumber": i + 1, "ETag": e} for i, e in enumerate(etags)]
        },
    )
elif cmd == "head":
    r = s3.head_object(Bucket=BUCKET, Key=args[0])
    print(json.dumps({"size": r["ContentLength"], "etag": r["ETag"]}))
else:
    sys.exit(f"unknown command {cmd}")
