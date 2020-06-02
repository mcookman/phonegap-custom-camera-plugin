
package com.performanceactive.plugins.camera;

import android.app.Activity;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.content.res.Configuration;
import android.graphics.Bitmap;
import android.graphics.Bitmap.CompressFormat;
import android.graphics.BitmapFactory;
import android.graphics.Color;
import android.graphics.Matrix;
import android.graphics.Point;
import android.hardware.Camera;
import android.graphics.Typeface;
import android.hardware.Camera.AutoFocusCallback;
import android.hardware.Camera.PictureCallback;
import android.hardware.Camera.ShutterCallback;
import android.net.Uri;
import android.os.AsyncTask;
import android.os.Bundle;
import android.util.Log;
import android.view.MotionEvent;
import android.view.View;

import android.view.Gravity;
import android.view.ViewGroup.LayoutParams;
import android.view.Window;
import android.view.WindowManager;
import android.widget.FrameLayout;
import android.widget.ImageButton;
import android.widget.ImageView;
import android.widget.ImageView.ScaleType;
import android.widget.RelativeLayout;
import android.widget.TextView;
import android.widget.LinearLayout;






import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.util.List;

import static android.hardware.Camera.Parameters.FLASH_MODE_OFF;
import static android.hardware.Camera.Parameters.FLASH_MODE_AUTO;
import static android.hardware.Camera.Parameters.FOCUS_MODE_AUTO;
import static android.hardware.Camera.Parameters.FOCUS_MODE_CONTINUOUS_PICTURE;

public class CustomCameraActivity extends Activity {

    private static final String TAG = CustomCameraActivity.class.getSimpleName();
    private static final float ASPECT_RATIO = 126.0f / 86;

    public static String FILENAME = "Filename";
    public static String QUALITY = "Quality";
    public static String TARGET_WIDTH = "TargetWidth";
    public static String TARGET_HEIGHT = "TargetHeight";
    public static String IMAGE_URI = "ImageUri";
    public static String ERROR_MESSAGE = "ErrorMessage";
	public static String TOP_MESSAGE = "Top Message";
	public static String TMP_PATH = "TMP_Path";
    public static int RESULT_ERROR = 2;

    private Camera camera = null;
    private RelativeLayout layout;
    private FrameLayout cameraPreviewView;
    private ImageView borderTopLeft;
    private ImageView borderTopRight;
    private ImageView borderBottomLeft;
    private ImageView borderBottomRight;
	private TextView topMessage;
	private TextView statusMessage;
    private ImageButton captureButton;
	private ImageButton cancelButton;

	private int camLeft = 0;
	private int camTop = 0;
	private int camWidth = 0;
	private int camHeight = 0;
	private int maxPicWidth = 0;
	private int maxPicHeight = 0;
    Camera.Size optimalSize = null;
    @Override
    protected void onResume() {
        super.onResume();
        try {
            camera = Camera.open();
            configureCamera();
            displayCameraPreview();
			statusMessage.setText("Ready");
        } catch (Exception e) {
            finishWithError("Camera is not accessible");
        }
    }

    private void configureCamera() {
        Camera.Parameters cameraSettings = camera.getParameters();
        cameraSettings.setJpegQuality(100);
        List<String> supportedFocusModes = cameraSettings.getSupportedFocusModes();
        if (supportedFocusModes.contains(Camera.Parameters.FOCUS_MODE_CONTINUOUS_PICTURE)) {
            cameraSettings.setFocusMode(Camera.Parameters.FOCUS_MODE_CONTINUOUS_PICTURE);
        } else if (supportedFocusModes.contains(Camera.Parameters.FOCUS_MODE_AUTO)) {
            cameraSettings.setFocusMode(Camera.Parameters.FOCUS_MODE_AUTO);
        }

		//now set the picture size to be the max calculated
        cameraSettings.setPictureSize(maxPicWidth, maxPicHeight);

        camera.setParameters(cameraSettings);
    }

    private void displayCameraPreview() {
        cameraPreviewView.removeAllViews();
        cameraPreviewView.addView(new CustomCameraPreview(this, camera, camWidth, camHeight));
    }

    @Override
    protected void onPause() {
        super.onPause();
        releaseCamera();
    }

    private void releaseCamera() {
        if (camera != null) {
            camera.stopPreview();
            camera.release();
            camera = null;
        }
    }

    private int calcCamPicSize(int screenwidth, int screenheight){
        if(camera == null){
            camera = Camera.open();
        }
        if(screenwidth > screenheight) {
            double nh = screenheight * .90;
            camHeight = (int) Math.round(nh);

            List<Camera.Size> sizes = camera.getParameters().getSupportedPreviewSizes();
            double screenAspect = screenwidth / screenheight;

            double minimumAspectDelta = Float.MAX_VALUE;

            for (Camera.Size size : sizes) {
                double camAspect = (double) size.width / size.height;
                if (screenAspect - camAspect < minimumAspectDelta) {
                    optimalSize = size;
                    minimumAspectDelta = screenAspect - camAspect;
                }
            }
            camWidth = (int)Math.round((optimalSize.height * camHeight)/optimalSize.width);
        } else {
            double nw = screenwidth * .95;
            camWidth = (int)Math.round(nw);

            List<Camera.Size> sizes = camera.getParameters().getSupportedPreviewSizes();
            double screenAspect = screenheight / screenwidth;
            double minimumAspectDelta = Float.MAX_VALUE;

            for (Camera.Size size : sizes) {
                double camAspect = (double) size.width / size.height;

                if (screenAspect - camAspect < minimumAspectDelta) {
                    optimalSize = size;
                    minimumAspectDelta = screenAspect - camAspect;
                }
            }
            camHeight = (int)Math.round((optimalSize.width * camWidth)/optimalSize.height);

        }

        //now calculate the max pic size at the aspect calculated
        double cAspect = (double)camWidth/(double)camHeight;
        List<Camera.Size> sizes = camera.getParameters().getSupportedPictureSizes();
        Camera.Size maxWSize = sizes.get(0);
        maxWSize.height = 0;
        maxWSize.width = 0;
        for (Camera.Size size : sizes) {
            double camAspect = (double) size.height / size.width;
            if(camAspect == cAspect){
                if(size.width > maxWSize.width )
                    maxWSize = size;
            }

        }
        maxPicWidth = maxWSize.width;
        maxPicHeight = maxWSize.height;
        return 1;
    }
    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        getWindow().setFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN, WindowManager.LayoutParams.FLAG_FULLSCREEN);
        requestWindowFeature(Window.FEATURE_NO_TITLE);
        layout = new RelativeLayout(this);
        RelativeLayout.LayoutParams layoutParams = new RelativeLayout.LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT);
        layout.setLayoutParams(layoutParams);

        //calculate the desired height of the preview
		int width = screenWidthInPixels();
		int height = screenHeightInPixels();

        if(calcCamPicSize(width, height) != 1){

        }

        camLeft = (int)Math.round((width - camWidth)/2.0);
        camTop = (int)Math.round((height - camHeight)/2.0);

        createCameraPreview();
		createTopMessage();
		createStatusMessage();
        createTopLeftBorder();
        createTopRightBorder();
        //createBottomLeftBorder();
        //createBottomRightBorder();
        //layoutBottomBorderImagesRespectingAspectRatio();
        createCaptureButton();
		createCancelButton();
		
		getWindow().getDecorView().setBackgroundColor(Color.BLACK);
        setContentView(layout);
		
    }

    private void createCameraPreview() {
        cameraPreviewView = new FrameLayout(this);
        //FrameLayout.LayoutParams layoutParams = new FrameLayout.LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT);


		//FrameLayout.LayoutParams layoutParams = new FrameLayout.LayoutParams(nnw, nnh, Gravity.CENTER_HORIZONTAL | Gravity.CENTER_VERTICAL);
		RelativeLayout.LayoutParams layoutParams = new RelativeLayout.LayoutParams(camWidth,camHeight);
		//layoutParams.addRule(RelativeLayout.CENTER_IN_PARENT)
		layoutParams.setMargins(camLeft, camTop, camLeft, camTop);
		
        cameraPreviewView.setLayoutParams(layoutParams);
        layout.addView(cameraPreviewView);
    }

    private void createTopLeftBorder() {
        borderTopLeft = new ImageView(this);
        setBitmap(borderTopLeft, "border_top_left.png");
        RelativeLayout.LayoutParams layoutParams = new RelativeLayout.LayoutParams(dpToPixels(50), dpToPixels(50));
        layoutParams.addRule(RelativeLayout.ALIGN_PARENT_TOP);
        layoutParams.addRule(RelativeLayout.ALIGN_PARENT_LEFT);
		layoutParams.topMargin = camTop;
		if(camLeft > 0)
		    layoutParams.leftMargin = camLeft;
		else
		    layoutParams.leftMargin = 0;
        /*if (isXLargeScreen()) {
            layoutParams.topMargin = dpToPixels(100);
            layoutParams.leftMargin = dpToPixels(100);
        } else if (isLargeScreen()) {
            layoutParams.topMargin = dpToPixels(50);
            layoutParams.leftMargin = dpToPixels(50);
        } else {
            layoutParams.topMargin = dpToPixels(40);
            layoutParams.leftMargin = dpToPixels(10);
        }*/
        borderTopLeft.setLayoutParams(layoutParams);
        layout.addView(borderTopLeft);
    }

    private void createTopRightBorder() {
        borderTopRight = new ImageView(this);
        setBitmap(borderTopRight, "border_top_right.png");
        RelativeLayout.LayoutParams layoutParams = new RelativeLayout.LayoutParams(dpToPixels(50), dpToPixels(50));
        layoutParams.addRule(RelativeLayout.ALIGN_PARENT_TOP);
        layoutParams.addRule(RelativeLayout.ALIGN_PARENT_RIGHT);
		layoutParams.topMargin = camTop;
		if(camLeft > 0)
		    layoutParams.rightMargin = camLeft;
		else
		    layoutParams.rightMargin = 0;
        /*if (isXLargeScreen()) {
            layoutParams.topMargin = dpToPixels(100);
            layoutParams.rightMargin = dpToPixels(100);
        } else if (isLargeScreen()) {
            layoutParams.topMargin = dpToPixels(50);
            layoutParams.rightMargin = dpToPixels(50);
        } else {
            layoutParams.topMargin = dpToPixels(40);
            layoutParams.rightMargin = dpToPixels(10);
        }*/
        borderTopRight.setLayoutParams(layoutParams);
        layout.addView(borderTopRight);
    }

    private void createBottomLeftBorder() {
        borderBottomLeft = new ImageView(this);
        setBitmap(borderBottomLeft, "border_bottom_left.png");
        RelativeLayout.LayoutParams layoutParams = new RelativeLayout.LayoutParams(dpToPixels(50), dpToPixels(50));
        layoutParams.addRule(RelativeLayout.ALIGN_PARENT_BOTTOM);
        layoutParams.addRule(RelativeLayout.ALIGN_PARENT_LEFT);
		layoutParams.bottomMargin = camTop;
		layoutParams.leftMargin = camLeft;
        /*if (isXLargeScreen()) {
            layoutParams.leftMargin = dpToPixels(100);
        } else if (isLargeScreen()) {
            layoutParams.leftMargin = dpToPixels(50);
        } else {
            layoutParams.leftMargin = dpToPixels(10);
        }*/
        borderBottomLeft.setLayoutParams(layoutParams);
        layout.addView(borderBottomLeft);
    }

    private void createBottomRightBorder() {
        borderBottomRight = new ImageView(this);
        setBitmap(borderBottomRight, "border_bottom_right.png");
        RelativeLayout.LayoutParams layoutParams = new RelativeLayout.LayoutParams(dpToPixels(50), dpToPixels(50));
        layoutParams.addRule(RelativeLayout.ALIGN_PARENT_BOTTOM);
        layoutParams.addRule(RelativeLayout.ALIGN_PARENT_RIGHT);
		layoutParams.bottomMargin = camTop;
		layoutParams.rightMargin = camLeft;
        /*if (isXLargeScreen()) {
            layoutParams.rightMargin = dpToPixels(100);
        } else if (isLargeScreen()) {
            layoutParams.rightMargin = dpToPixels(50);
        } else {
            layoutParams.rightMargin = dpToPixels(10);
        }*/
        borderBottomRight.setLayoutParams(layoutParams);
        layout.addView(borderBottomRight);
    }

    private void layoutBottomBorderImagesRespectingAspectRatio() {
        RelativeLayout.LayoutParams borderTopLeftLayoutParams = (RelativeLayout.LayoutParams)borderTopLeft.getLayoutParams();
        RelativeLayout.LayoutParams borderTopRightLayoutParams = (RelativeLayout.LayoutParams)borderTopRight.getLayoutParams();
        RelativeLayout.LayoutParams borderBottomLeftLayoutParams = (RelativeLayout.LayoutParams)borderBottomLeft.getLayoutParams();
        RelativeLayout.LayoutParams borderBottomRightLayoutParams = (RelativeLayout.LayoutParams)borderBottomRight.getLayoutParams();
        float height = (screenWidthInPixels() - borderTopRightLayoutParams.rightMargin - borderTopLeftLayoutParams.leftMargin) * ASPECT_RATIO;
        borderBottomLeftLayoutParams.bottomMargin = screenHeightInPixels() - Math.round(height) - borderTopLeftLayoutParams.topMargin;
        borderBottomLeft.setLayoutParams(borderBottomLeftLayoutParams);
        borderBottomRightLayoutParams.bottomMargin = screenHeightInPixels() - Math.round(height) - borderTopRightLayoutParams.topMargin;
        borderBottomRight.setLayoutParams(borderBottomRightLayoutParams);
    }

    private int screenWidthInPixels() {
        Point size = new Point();
        getWindowManager().getDefaultDisplay().getSize(size);
        return size.x;
    }

    private int screenHeightInPixels() {
        Point size = new Point();
        getWindowManager().getDefaultDisplay().getSize(size);
        return size.y;
    }

    private void createCaptureButton() {
        captureButton = new ImageButton(getApplicationContext());
        setBitmap(captureButton, "capture_button.png");
        captureButton.setBackgroundColor(Color.TRANSPARENT);
        captureButton.setScaleType(ScaleType.FIT_CENTER);
        RelativeLayout.LayoutParams layoutParams = new RelativeLayout.LayoutParams(dpToPixels(125), dpToPixels(125));
        layoutParams.addRule(RelativeLayout.ALIGN_PARENT_BOTTOM);
        layoutParams.addRule(RelativeLayout.CENTER_HORIZONTAL);
        layoutParams.bottomMargin = dpToPixels(2);
        captureButton.setLayoutParams(layoutParams);
        captureButton.setOnTouchListener(new View.OnTouchListener() {
            @Override
            public boolean onTouch(View v, MotionEvent event) {
                setCaptureButtonImageForEvent(event);
                return false;
            }
        });
        captureButton.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                takePictureWithAutoFocus();
            }
        });
        layout.addView(captureButton);
    }

	private void createCancelButton() {
        cancelButton = new ImageButton(getApplicationContext());
        setBitmap(cancelButton, "back_button.png");
        cancelButton.setBackgroundColor(Color.TRANSPARENT);
        cancelButton.setScaleType(ScaleType.FIT_XY);
        RelativeLayout.LayoutParams layoutParams = new RelativeLayout.LayoutParams(dpToPixels(60), dpToPixels(60));
        layoutParams.addRule(RelativeLayout.ALIGN_PARENT_BOTTOM);
        layoutParams.addRule(RelativeLayout.ALIGN_PARENT_LEFT);
        layoutParams.bottomMargin = 0;
        if(camLeft > 0)
		    layoutParams.leftMargin = camLeft;
        else
            layoutParams.leftMargin = 0;
        cancelButton.setLayoutParams(layoutParams);
        cancelButton.setOnTouchListener(new View.OnTouchListener() {
            @Override
            public boolean onTouch(View v, MotionEvent event) {
                setCancelButtonImageForEvent(event);
                return false;
            }
        });
        cancelButton.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                cancelOperation();
            }
        });
        layout.addView(cancelButton);
    }
	private void createTopMessage(){
		topMessage = new TextView(getApplicationContext());
		topMessage.setBackgroundColor(Color.TRANSPARENT);
		topMessage.setText(getIntent().getStringExtra(TOP_MESSAGE));
		topMessage.setPadding(0, 0, 0, 0);
		topMessage.setTextColor(Color.WHITE);
		topMessage.setWidth(screenWidthInPixels());
		topMessage.setHeight(50);
		topMessage.setTypeface(Typeface.SANS_SERIF, Typeface.BOLD);
		topMessage.setTextSize(14);
		RelativeLayout.LayoutParams layoutParams = new RelativeLayout.LayoutParams(RelativeLayout.LayoutParams.FILL_PARENT, 
                                                RelativeLayout.LayoutParams.WRAP_CONTENT);
        layoutParams.addRule(RelativeLayout.ALIGN_PARENT_TOP);
		layoutParams.addRule(RelativeLayout.ALIGN_PARENT_LEFT);
		layoutParams.setMargins(0, 0, 0, 0);
		topMessage.setLayoutParams(layoutParams);
		topMessage.setGravity(Gravity.CENTER);
		layout.addView(topMessage);
	}

	private void createStatusMessage(){
		statusMessage = new TextView(getApplicationContext());
		statusMessage.setBackgroundColor(Color.TRANSPARENT);
		statusMessage.setText(getIntent().getStringExtra(TOP_MESSAGE));
		statusMessage.setPadding(0, 0, 0, 0);
		statusMessage.setTextColor(Color.WHITE);
		statusMessage.setWidth(100);
		statusMessage.setHeight(55);
		statusMessage.setTypeface(Typeface.SANS_SERIF, Typeface.BOLD);
		statusMessage.setTextSize(14);
		
		RelativeLayout.LayoutParams layoutParams = new RelativeLayout.LayoutParams(RelativeLayout.LayoutParams.FILL_PARENT, 
                                                RelativeLayout.LayoutParams.WRAP_CONTENT);
        layoutParams.addRule(RelativeLayout.ALIGN_PARENT_BOTTOM);
		layoutParams.addRule(RelativeLayout.ALIGN_PARENT_RIGHT);
		layoutParams.bottomMargin = dpToPixels(10);
		layoutParams.rightMargin = dpToPixels(20);
		//layoutParams.leftMargin = dpToPixels(screenWidthInPixels() - 250);
		statusMessage.setLayoutParams(layoutParams);
		statusMessage.setGravity(Gravity.RIGHT);
		statusMessage.setText("Ready");
		layout.addView(statusMessage);

	}
    private void setCaptureButtonImageForEvent(MotionEvent event) {
        if (event.getAction() == MotionEvent.ACTION_DOWN) {
            setBitmap(captureButton, "capture_button_pressed.png");
        } else if (event.getAction() == MotionEvent.ACTION_UP) {
            setBitmap(captureButton, "capture_button.png");
        }
    }

	private void setCancelButtonImageForEvent(MotionEvent event) {
        if (event.getAction() == MotionEvent.ACTION_DOWN) {
            setBitmap(cancelButton, "back_button_pressed.png");
        } else if (event.getAction() == MotionEvent.ACTION_UP) {
            setBitmap(cancelButton, "back_button.png");
        }
    }

    private void takePictureWithAutoFocus() {
		takePicture();
		
        /*if (getPackageManager().hasSystemFeature(PackageManager.FEATURE_CAMERA_AUTOFOCUS)) {
		    statusMessage.setText("Focusing...");
            camera.autoFocus(new AutoFocusCallback() {
                @Override
                public void onAutoFocus(boolean success, Camera camera) {
                    takePicture();
                }
            });
        } else {
            takePicture();
        }*/
    }

    private void takePicture() {
        try {
			ShutterCallback shutterCallback = new ShutterCallback() {
			    @Override
				public void onShutter() { 
					/* Empty Callbacks play a sound! */
				}
			};
			statusMessage.setText("Taking Picture...");
            camera.takePicture(shutterCallback, null, new PictureCallback() {
                @Override
                public void onPictureTaken(byte[] jpegData, Camera camera) {
                    new OutputCapturedImageTask().execute(jpegData);
                }
				
            });
			
        } catch (Exception e) {
            finishWithError("Failed to take image");
        }
    }

	private void cancelOperation() {
		Intent data = new Intent().putExtra(ERROR_MESSAGE, "cancel");
		setResult(RESULT_OK, data);
		finish();
	}
    private class OutputCapturedImageTask extends AsyncTask<byte[], Void, Void> {

        @Override
        protected Void doInBackground(byte[]... jpegData) {
            try {
                String filename = getIntent().getStringExtra(FILENAME);
                int quality = getIntent().getIntExtra(QUALITY, 80);
                //File capturedImageFile = new File(getCacheDir(), filename);
				File capturedImageFile = new File(getIntent().getStringExtra(TMP_PATH), filename);
                Bitmap capturedImage = getScaledBitmap(jpegData[0]);
                capturedImage = correctCaptureImageOrientation(capturedImage);
                capturedImage.compress(CompressFormat.JPEG, quality, new FileOutputStream(capturedImageFile));
				
                Intent data = new Intent();
                data.putExtra(IMAGE_URI, Uri.fromFile(capturedImageFile).toString());
                setResult(RESULT_OK, data);
                finish();
            } catch (Exception e) {
                finishWithError("Failed to save image");
            }
            return null;
        }

    }

	


    private Bitmap getScaledBitmap(byte[] jpegData) {
        int targetWidth = getIntent().getIntExtra(TARGET_WIDTH, -1);
        int targetHeight = getIntent().getIntExtra(TARGET_HEIGHT, -1);
        if (targetWidth <= 0 && targetHeight <= 0) {
            return BitmapFactory.decodeByteArray(jpegData, 0, jpegData.length);
        }

        // get dimensions of image without scaling
        BitmapFactory.Options options = new BitmapFactory.Options();
        options.inJustDecodeBounds = true;
        BitmapFactory.decodeByteArray(jpegData, 0, jpegData.length, options);

        // decode image as close to requested scale as possible
        options.inJustDecodeBounds = false;
        options.inSampleSize = calculateInSampleSize(options, targetWidth, targetHeight);
        Bitmap bitmap = BitmapFactory.decodeByteArray(jpegData, 0, jpegData.length, options);

        // set missing width/height based on aspect ratio
        float aspectRatio = ((float)options.outHeight) / options.outWidth;
        if (targetWidth > 0 && targetHeight <= 0) {
            targetHeight = Math.round(targetWidth * aspectRatio);
        } else if (targetWidth <= 0 && targetHeight > 0) {
            targetWidth = Math.round(targetHeight / aspectRatio);
        }

        // make sure we also
        Matrix matrix = new Matrix();
        matrix.postRotate(90);
        return Bitmap.createScaledBitmap(bitmap, targetWidth, targetHeight, true);
    }

    private int calculateInSampleSize(BitmapFactory.Options options, int requestedWidth, int requestedHeight) {
        int originalHeight = options.outHeight;
        int originalWidth = options.outWidth;
        int inSampleSize = 1;
        if (originalHeight > requestedHeight || originalWidth > requestedWidth) {
            int halfHeight = originalHeight / 2;
            int halfWidth = originalWidth / 2;
            while ((halfHeight / inSampleSize) > requestedHeight && (halfWidth / inSampleSize) > requestedWidth) {
                inSampleSize *= 2;
            }
        }
        return inSampleSize;
    }

    private Bitmap correctCaptureImageOrientation(Bitmap bitmap) {
        Matrix matrix = new Matrix();
        matrix.postRotate(90);
        return Bitmap.createBitmap(bitmap, 0, 0, bitmap.getWidth(), bitmap.getHeight(), matrix, true);
    }

    private void finishWithError(String message) {
        Intent data = new Intent().putExtra(ERROR_MESSAGE, message);
        setResult(RESULT_ERROR, data);
        finish();
    }

    private int dpToPixels(int dp) {
        float density = getResources().getDisplayMetrics().density;
        return Math.round(dp * density);
    }

    private boolean isXLargeScreen() {
        int screenLayout = getResources().getConfiguration().screenLayout;
        return (screenLayout & Configuration.SCREENLAYOUT_SIZE_MASK) == Configuration.SCREENLAYOUT_SIZE_XLARGE;
    }

    private boolean isLargeScreen() {
        int screenLayout = getResources().getConfiguration().screenLayout;
        return (screenLayout & Configuration.SCREENLAYOUT_SIZE_MASK) == Configuration.SCREENLAYOUT_SIZE_LARGE;
    }

    private void setBitmap(ImageView imageView, String imageName) {
        try {
            InputStream imageStream = getAssets().open("www/img2/cameraoverlay/" + imageName);
            Bitmap bitmap = BitmapFactory.decodeStream(imageStream);
            imageView.setImageBitmap(bitmap);
            imageStream.close();
        } catch (Exception e) {
            Log.e(TAG, "Could load image", e);
        }
    }

}
