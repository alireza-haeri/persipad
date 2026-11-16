"""Regression tests for the shell patterns used to verify APK contents."""
import re
import subprocess
import unittest
from pathlib import Path


class ApkVerificationPatternsTest(unittest.TestCase):
    def test_apk_paths_match_real_entries_only(self):
        workflow = Path('.github/workflows/android.yml').read_text()
        examples = {
            'LIBAPP': ('lib/arm64-v8a/libapp.so', 'lib/arm64-v8a/libappXso'),
            'LIBFLUTTER': ('lib/arm64-v8a/libflutter.so', 'lib/arm64-v8a/libflutterXso'),
            'KERNEL_BLOB': ('assets/flutter_assets/kernel_blob.bin', 'assets/flutter_assets/kernel_blobXbin'),
            'DEX': ('classes2.dex', 'classes2Xdex'),
        }
        for variable, (valid, invalid) in examples.items():
            with self.subTest(variable=variable):
                match = re.search(rf"{variable}=\$\(unzip -l .*?grep -c(E?) '([^']+)'", workflow)
                self.assertIsNotNone(match, variable)
                flag, pattern = match.groups()
                for filename, expected in [(valid, 0), (invalid, 1)]:
                    result = subprocess.run(['grep', '-E' if flag else '-G', pattern],
                                            input=filename + '\n', text=True, capture_output=True)
                    self.assertEqual(result.returncode, expected, (variable, filename, pattern))

    def test_signature_verification_fails_closed(self):
        workflow = Path('.github/workflows/android.yml').read_text()
        verify = workflow.split('      - name: Verify the APK', 1)[1].split('      - name: Publish', 1)[0]
        self.assertIn('if ! APKSIGNER_OUT=$("$BUILD_TOOLS/apksigner" verify --print-certs "$APK" 2>&1); then', verify)
        self.assertIn('APK signature verification failed', verify)
        self.assertIn('exit 1', verify.split('APK signature verification failed', 1)[1].split('fi', 1)[0])

    def test_apk_test_marker_does_not_publish(self):
        workflow = Path('.github/workflows/android.yml').read_text()
        job = workflow.split('  apk:', 1)[1].split('    runs-on:', 1)[0]
        publish = workflow.split('      - name: Publish the pre-release', 1)[1].split('        env:', 1)[0]
        self.assertIn("'[apk-test]'", job)
        self.assertNotIn("'[apk-test]'", publish)
        self.assertIn("'[apk]'", publish)


if __name__ == '__main__':
    unittest.main()
