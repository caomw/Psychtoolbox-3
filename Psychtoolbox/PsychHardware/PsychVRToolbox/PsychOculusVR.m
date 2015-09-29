function varargout = PsychOculusVR(cmd, varargin)
% PsychOculusVR - A high level driver for Oculus VR hardware.
%
% Usage:
%
% hmd = PsychOculusVR('AutoSetupHMD' [, basicTask='Tracked3DVR'][, basicRequirements][, basicQuality=0][, deviceIndex]);
% - Open a Oculus HMD, set it up with good default rendering and
% display parameters and generate a PsychImaging('AddTask', ...)
% line to setup the Psychtoolbox imaging pipeline for proper display
% on the HMD. This will also cause the device connection to get
% auto-closed as soon as the onscreen window which displays on
% the HMD is closed. Returns the 'hmd' handle of the HMD on success.
%
% By default, the first detected HMD will be used and if no VR HMD
% is connected, it will open an emulated/simulated one for basic
% testing and debugging. You can override this default choice of
% HMD by specifying the optional 'deviceIndex' parameter to choose
% a specific HMD.
%
% More optional parameters: 'basicTask' what kind of task should be implemented.
% The default is 'Tracked3DVR', which means to setup for stereoscopic 3D
% rendering, driven by head motion tracking, for a fully immersive experience
% in some kind of 3D virtual world. This is the default if omitted. The task
% 'Stereoscopic' sets up for display of stereoscopic stimuli, but without
% head tracking. 'Monoscopic' sets up for display of monocular stimuli, ie.
% the HMD is just used as a special kind of standard display monitor.
%
% 'basicRequirements' defines basic requirements for the task. Currently
% defined are the following strings which can be combined into a single
% 'basicRequirements' string: 'LowPersistence' = Try to keep exposure
% time of visual images on the retina low if possible, ie., try to approximate
% a pulse-type display instead of a hold-type display if possible. This has
% no effect on the Rift DK1. On the Rift DK2 it will enable low persistence
% scanning of the OLED display panel, to light up each pixel only a fraction
% of a video refresh cycle duration.
%
% 'FastResponse' = Try to switch images with minimal delay and fast
% pixel switching time. This has no effect on the Rift DK1. On the DK2 it
% will enable OLED panel overdrive processing. OLED panel overdrive processing
% is a relatively expensive post processing step.
%
% 'TimingSupport' = Support some hardware specific means of timestamping
% or latency measurements. On the Rift DK1 this does nothing. On the DK2
% it enables dynamic prediction and timing measurements with the Rifts internal
% latency tester.
%
% 'TimeWarp' = Enable per eye image 2D timewarping via prediction of eye
% poses at scanout time. This mostly only makes sense for head-tracked 3D
% rendering. Depending on 'basicQuality' a more cheap or more expensive
% procedure is used.
%
% 'basicQuality' defines the basic tradeoff between quality and required
% computational power. A setting of 0 gives lowest quality, but with the
% lowest performance requirements. A setting of 1 gives maximum quality at
% maximum computational load. Values between 0 and 1 change the quality to
% performance tradeoff.
%
%
% hmd = PsychOculusVR('Open' [, deviceIndex], ...);
% - Open HMD with index 'deviceIndex'. See PsychOculusVRCore Open?
% for help on additional parameters.
%
%
% PsychOculusVR('SetAutoClose', hmd, mode);
% - Set autoclose mode for HMD with handle 'hmd'. 'mode' can be
% 0 (this is the default) to not do anything special. 1 will close
% the HMD 'hmd' when the onscreen window is closed which displays
% on the HMD. 2 will do the same as 1, but close all open HMDs and
% shutdown the complete driver and Oculus runtime - a full cleanup.
%
%
% isOpen = PsychOculusVR('IsOpen', hmd);
% - Returns 1 if 'hmd' corresponds to an open HMD, 0 otherwise.
%
%
% PsychOculusVR('Close' [, hmd])
% - Close provided HMD device 'hmd'. If no 'hmd' handle is provided,
% all HMDs will be closed and the driver will be shutdown.
%
%
% info = PsychOculusVR('GetInfo', hmd);
% - Retrieve a struct 'info' with information about the HMD 'hmd'.
% The returned info struct contains at least the following standardized
% fields with information:
% handle = Driver internal handle for the specific HMD.
% driver = Function handle to the actual driver for the HMD, e.g., @PsychOculusVR.
% type   = Defines the type/vendor of the device, e.g., 'Oculus'.
% modelName = Name string with the name of the model of the device, e.g., 'Rift DK2'.
% separateEyePosesSupported = 1 if use of PsychOculusVR('GetEyePose') will improve
%                             the quality of the VR experience, 0 if no improvement
%                             is to be expected, so 'GetEyePose' can be avoided
%                             to save processing time without a loss of quality.
%                             This always returns 1 for at least the Rift DK1 and DK2,
%                             as use of that function can enhance the quality of the
%                             VR experience with fast head movements.
%
% The returned struct may contain more information, but the fields mentioned
% above are the only ones guaranteed to be available over the long run. Other
% fields may disappear or change their format and meaning anytime without
% warning.
%
%
% isSupported = PsychOculusVRCore('Supported');
% - Returns 1 if the Oculus driver is functional, 0 otherwise. The
% driver is functional if the VR runtime library was successfully
% initialized and a connection to the VR server process has been
% established. It would return 0 if the server process would not be
% running, or if the required runtime library would not be correctly
% installed.
%
%
% state = PsychOculusVRCore('PrepareRender', hmd [, userTransformMatrix][, reqmask=1][, targetTime]);
% - Mark the start of the rendering cycle for a new 3D rendered stereoframe.
% Return a struct 'state' which contains various useful bits of information
% for 3D stereoscopic rendering of a scene, based on head tracking data.
%
% 'hmd' is the handle of the HMD which delivers tracking data and receives the
% rendered content for display.
%
% 'reqmask' defines what kind of information is requested to be returned in
% struct 'state'. Only query information you actually need, as computing some
% of this info is expensive! See below for supported values for 'reqmask'.
%
% 'targetTime' is the expected time at which the rendered frame will display.
% This could potentially be used by the driver to make better predictions of
% camera/eye/head pose for the image. Omitting the value will use a target time
% that is implementation specific, but known to give generally good results,
% e.g., the midpoint of scanout of the next video frame.
%
% 'userTransformMatrix' is an optional 4x4 right hand side (RHS) transformation
% matrix. It gets applied to the tracked head pose as a global transformation
% before computing results based on head pose like, e.g., camera transformations.
% You can use this to translate the "virtual head" and thereby the virtual eyes/
% cameras in the 3D scene, so observer motion is not restricted to the real world
% tracking volume of your headset. A typical 'userTransformMatrix' would be a
% combined translation and rotation matrix to position the observer at some
% 3D location in space, then define his/her global looking direction, aka as
% heading angle, yaw orientation, or rotation around the y-axis in 3D space.
% Head pose tracking results would then operate relative to this global transform.
% If 'userTransformMatrix' is left out, it will default to an identity transform,
% in other words, it will do nothing.
%
%
% state always contains a field state.tracked, whose bits signal the status
% of head tracking for this frame. A +1 flag means that head orientation is
% tracked. A +2 flag means that head position is tracked via some absolute
% position tracker like, e.g., the Oculus Rift DK2 camera.
%
% 'reqmask' defaults to 1 and can have the following values added together:
%
% +1 = Return matrices for left and right "eye cameras" which can be directly
%      used as OpenGL GL_MODELVIEW matrices for rendering the scene. 4x4 matrices
%      for left- and right eye are contained in state.modelView{1} and {2}.
%
%      Return position and orientation 4x4 camera view matrices which describe
%      position and orientation of the "eye cameras" relative to the world
%      reference frame. They are the inverses of state.modelView{}. These
%      matrices can be directly used to define cameras for rendering of complex
%      3D scenes with the Horde3D 3D engine. Left- and right eye matrices are
%      contained in state.cameraView{1} and {2}.
%
%      Additionally tracked/predicted head pose is returned in state.localHeadPoseMatrix
%      and the global head pose after application of the 'userTransformMatrix' is
%      returned in state.globalHeadPoseMatrix - this is the basis for computing
%      the camera transformation matrices.
%
% More flags to follow...
%
%
% eyePose = PsychOculusVR('GetEyePose', hmd, renderPass [, userTransformMatrix][, targetTime]);
% - Return a struct 'eyePose' which contains various useful bits of information
% for 3D stereoscopic rendering of the stereo view of one eye, based on head
% tracking data. This function provides essentially the same information as
% the 'PrepareRender' function, but only for one eye. Therefore you will need
% to call this function twice, once for each of the two renderpasses, at the
% beginning of each renderpass.
%
% 'hmd' is the handle of the HMD which delivers tracking data and receives the
% rendered content for display.
%
% 'renderPass' defines if information should be returned for the 1st renderpass
% (renderPass == 0) or for the 2nd renderpass (renderPass == 1). The driver will
% decide for you if the 1st renderpass should render the left eye and the 2nd
% pass the right eye, or if the 1st renderpass should render the right eye and
% then the 2nd renderpass the left eye. The ordering depends on the properties
% of the video display of your HMD, specifically on the video scanout order:
% Is it right to left, left to right, or top to bottom? For each scanout order
% there is an optimal order for the renderpasses to minimize perceived lag.
%
% 'targetTime' is the expected time at which the rendered frame will display.
% This could potentially be used by the driver to make better predictions of
% camera/eye/head pose for the image. Omitting the value will use a target time
% that is implementation specific, but known to give generally good results.
%
% 'userTransformMatrix' is an optional 4x4 right hand side (RHS) transformation
% matrix. It gets applied to the tracked head pose as a global transformation
% before computing results based on head pose like, e.g., camera transformations.
% You can use this to translate the "virtual head" and thereby the virtual eyes/
% cameras in the 3D scene, so observer motion is not restricted to the real world
% tracking volume of your headset. A typical 'userTransformMatrix' would be a
% combined translation and rotation matrix to position the observer at some
% 3D location in space, then define his/her global looking direction, aka as
% heading angle, yaw orientation, or rotation around the y-axis in 3D space.
% Head pose tracking results would then operate relative to this global transform.
% If 'userTransformMatrix' is left out, it will default to an identity transform,
% in other words, it will do nothing.
%
% Return values in struct 'eyePose':
%
% 'eyeIndex' The eye for which this information applies. 0 = Left eye, 1 = Right eye.
%            You can pass 'eyeIndex' into the Screen('SelectStereoDrawBuffer', win, eyeIndex)
%            to select the proper eye target render buffer.
%
% 'modelView' is a 4x4 RHS OpenGL matrix which can be directly used as OpenGL
%             GL_MODELVIEW matrix for rendering the scene.
%
% 'cameraView' contains a 4x4 RHS camera matrix which describes position and
%              orientation of the "eye camera" relative to the world reference
%              frame. It is the inverse of eyePose.modelView. This matrix can
%              be directly used to define the camera for rendering of complex
%              3D scenes with the Horde3D 3D engine or other engines which want
%              absolute camera pose instead of the inverse matrix.
%
% Additionally tracked/predicted head pose is returned in eyePose.localHeadPoseMatrix
% and the global head pose after application of the 'userTransformMatrix' is
% returned in eyePose.globalHeadPoseMatrix - this is the basis for computing
% the camera transformation matrix.
%
%
% PsychOculusVR('SetupRenderingParameters', hmd [, basicTask='Tracked3DVR'][, basicRequirements][, basicQuality=0][, fov=[HMDRecommended]][, pixelsPerDisplay=1])
% - Query the HMD 'hmd' for its properties and setup internal rendering
% parameters in preparation for opening an onscreen window with PsychImaging
% to display properly on the HMD. See section about 'AutoSetupHMD' above for
% the meaning of the optional parameters 'basicTask', 'basicRequirements'
% and 'basicQuality'.
%
% 'fov' Optional field of view in degrees, from line of sight: [leftdeg, rightdeg,
% updeg, downdeg]. If 'fov' is omitted, the HMD runtime will be asked for a
% good default field of view and that will be used. The field of view may be
% dependent on the settings in the HMD user profile of the currently selected
% user.
%
% 'pixelsPerDisplay' Ratio of the number of render target pixels to display pixels
% at the center of distortion. Defaults to 1.0 if omitted. Lower values can
% improve performance, at lower quality.
%
%
% PsychOculusVR('SetBasicQuality', hmd, basicQuality);
% - Set basic level of quality vs. required GPU performance.
%
%
% oldSetting = PsychOculusVR('SetFastResponse', hmd [, enable]);
% - Return old setting for 'FastResponse' mode in 'oldSetting',
% optionally enable or disable the mode via specifying the 'enable'
% parameter as 1 or 0. Please note that if you want to use 'FastResponse',
% you must request and thereby enable it at the beginning of a session, as
% the driver must do some neccessary setup prep work at startup of the HMD.
% Once it was initially enabled, you can switch the setting at runtime with
% this function.
%
%
% oldSetting = PsychOculusVR('SetTimeWarp', hmd [, enable]);
% - Return old setting for 'TimeWarp' mode in 'oldSetting',
% optionally enable or disable the mode via specifying the 'enable'
% parameter as 1 or 0. Please note that if you want to use 'TimeWarp',
% you must request and thereby enable it at the beginning of a session, as
% the driver must do some neccessary setup prep work at startup of the HMD.
% Once it was initially enabled, you can switch the setting at runtime with
% this function.
%
%
% oldSetting = PsychOculusVR('SetLowPersistence', hmd [, enable]);
% - Return old setting for 'LowPersistence' mode in 'oldSetting',
% optionally enable or disable the mode via specifying the 'enable'
% parameter as 1 or 0.
%
%
% PsychOculusVR('SetHSWDisplayDismiss', hmd [, dismissTypes=1+2+4]);
% - Set how the user can dismiss the "Health and safety warning display".
% 'dismissTypes' can be -1 to disable the HSWD, or a value >= 0 to show
% the HSWD until a timeout and or until the user dismisses the HSWD.
% The following flags can be added to define type of dismissal:
%
% +0 = Display until timeout, if any. Will wait forever if there isn't any timeout!
% +1 = Dismiss via keyboard keypress.
% +2 = Dismiss via mouse click or mousepad tap.
% +4 = Dismiss via a tap to the HMD (detected via accelerometer).
%
%
% [bufferSize, imagingFlags, stereoMode] = PsychOculusVR('GetClientRenderingParameters', hmd);
% - Retrieve recommended size in pixels 'bufferSize' = [width, height] of the client
% renderbuffer for each eye for rendering to the HMD. Returns parameters
% previously computed by PsychOculusVR('SetupRenderingParameters', hmd).
%
% Also returns 'imagingFlags', the required imaging mode flags for setup of
% the Screen imaging pipeline. Also returns the needed 'stereoMode' for the
% pipeline.
%
%
% isOutput = PsychOculusVR('IsHMDOutput', hmd, scanout);
% - Returns 1 (true) if 'scanout' describes the video output to which the
% HMD 'hmd' is connected. 'scanout' is a struct returned by the Screen
% function Screen('ConfigureDisplay', 'Scanout', screenid, outputid);
% This allows probing video outputs to find the one which feeds the HMD.
%
%
% [headToEyeShiftv, headToEyeShiftMatrix] = PsychOculusVR('GetEyeShiftVector', hmd, eye);
% - Retrieve 3D translation vector [tx, ty, tz] that defines the 3D position of the given
% eye 'eye' for the given HMD 'hmd', relative to the origin of the local head/HMD
% reference frame. This is needed to translate a global head pose into a eye
% pose, e.g., to translate the output of PsychOculusVR('GetEyePose') into actual
% tracked/predicted eye locations for stereo rendering.
%
% In addition to the 'headToEyeShiftv' vector, a corresponding 4x4 translation
% matrix is also returned in 'headToEyeShiftMatrix' for convenience.
%
%

% History:
% 07-Sep-2015  mk   Written.

% Global GL handle for access to OpenGL constants needed in setup:
global GL;

persistent hmd;

if nargin < 1 || isempty(cmd)
  help PsychOculusVR;
  fprintf('\n\nAlso available are functions from PsychOculusVRCore:\n');
  PsychOculusVRCore;
  return;
end

% Fast-Path function 'TimeWarp'. Prepares 2D eye timewarp:
if cmd == 1
  handle = varargin{1};

  if hmd{handle}.useOverdrive
    % Find next output texture and bind it as 2nd rendertarget to the output fbo.
    % It will capture a copy of the rendered output frame, with geometry correction,
    % color aberration correction and vignette correction applied, but without the
    % overdrive processing. That copy will be used as reference for the next frame,
    % to compute per-pixel overdrive values:
    currentOverdriveTex = mod(hmd{handle}.lastOverdriveTex + 1, 2);
    glFramebufferTexture2D(GL.FRAMEBUFFER_EXT, GL.COLOR_ATTACHMENT1, GL.TEXTURE_RECTANGLE_EXT, hmd{handle}.overdriveTex(currentOverdriveTex + 1), 0);
    glDrawBuffers(2, [GL.COLOR_ATTACHMENT0, GL.COLOR_ATTACHMENT1]);

    % Bind lastOverdriveTex from previous presentation cycle as old image
    % to texture unit. It will be used for overdrive computation for this
    % frame rendercycle:
    glActiveTextureARB(GL.TEXTURE2);
    glBindTexture(GL.TEXTURE_RECTANGLE_EXT, hmd{handle}.overdriveTex(hmd{handle}.lastOverdriveTex + 1));
    glActiveTextureARB(GL.TEXTURE0);

    % Prepare next rendercycle already: Swap the textures.
    hmd{handle}.lastOverdriveTex = currentOverdriveTex;
  end

  if hmd{handle}.useTimeWarp
    if hmd{handle}.useTimeWarp > 1
      % Wait for warp point, then query warp matrices. We assume the warp point is
      % 3 msecs before the target vblank and use our own high precision estimation of
      % the warp point, as well as our own high precision wait. Oculus SDK v0.5 doesn't
      % implement warp point calculation properly itself, therefore "do it yourself":
      winfo = Screen('GetWindowInfo', hmd{handle}.win, 7);
      warpPointSecs = winfo.LastVBLTime + hmd{handle}.videoRefreshDuration - 0.003;
      WaitSecs('UntilTime', warpPointSecs);
    end

    % Get the matrices:
    [hmd{handle}.eyeRotStartMatrixLeft, hmd{handle}.eyeRotEndMatrixLeft] = PsychOculusVRCore('GetEyeTimewarpMatrices', handle, 0, 0);
    [hmd{handle}.eyeRotStartMatrixRight, hmd{handle}.eyeRotEndMatrixRight] = PsychOculusVRCore('GetEyeTimewarpMatrices', handle, 1, 0);

    % Setup left shaders warp matrices:
    glUseProgram(hmd{handle}.shaderLeft(1));
    glUniformMatrix4fv(hmd{handle}.shaderLeft(2), 1, 1, hmd{handle}.eyeRotStartMatrixLeft);
    glUniformMatrix4fv(hmd{handle}.shaderLeft(3), 1, 1, hmd{handle}.eyeRotEndMatrixLeft);

    % Setup right shaders warp matrices:
    glUseProgram(hmd{handle}.shaderRight(1));
    glUniformMatrix4fv(hmd{handle}.shaderRight(2), 1, 1, hmd{handle}.eyeRotStartMatrixRight);
    glUniformMatrix4fv(hmd{handle}.shaderRight(3), 1, 1, hmd{handle}.eyeRotEndMatrixRight);

    % Ready for warp:
    glUseProgram(0);
  end

  return;
end

if cmd == 2
  handle = varargin{1};
  latencyColor = PsychOculusVRCore('LatencyTester', handle, 0);
  if ~isempty(latencyColor)
    glColor3ubv(latencyColor);
    glPointSize(4);
    glBegin(GL.POINTS);
    glVertex2i(1,1);
    glEnd;
    glPointSize(1);
  end

  return;
end

if strcmpi(cmd, 'PrepareRender')
  % Get and validate handle - fast path open coded:
  myhmd = varargin{1};
  if ~((length(hmd) >= myhmd.handle) && (myhmd.handle > 0) && hmd{myhmd.handle}.open)
    error('PsychOculusVR:PrepareRender: Specified handle does not correspond to an open HMD!');
  end

  % Get 'userTransformMatrix' if any:
  if length(varargin) >= 2 && ~isempty(varargin{2})
    userTransformMatrix = varargin{2};
  else
    % Default: Identity transform to do nothing:
    userTransformMatrix = diag([1 1 1 1]);
  end

  % Valid: Get request mask of information to return:
  if length(varargin) >= 3 && ~isempty(varargin{3})
    reqmask = varargin{3};
  else
    % Default to: Provide basic tracking status flags, and directly useable
    % GL_MODELVIEW matrices for the cameras for rendering the left- and right-eye:
    reqmask = 1;
  end

  % Get target time for predicted camera poses, head poses etc.:
  if length(varargin) >= 4 && ~isempty(varargin{4})
    targetTime = varargin{4};
  else
    % Default: Provide predicted value for the midpoint of the next video
    % refresh cycle - assuming we hit the flip deadline for the next video
    % frame, so that point in time will be exactly in the middle of both
    % eyes:
    winfo = Screen('GetWindowInfo', hmd{myhmd.handle}.win);
    targetTime = winfo.LastVBLTime + 1.5 * hmd{myhmd.handle}.videoRefreshDuration;
  end

  % Mark start of a new frame render cycle for the runtime and get the data
  % predicted for next scanout time:
  [eyePose{1}, eyePose{2}, tracked] = PsychOculusVRCore('StartRender', myhmd.handle);

  % Always return basic tracking status:
  result.tracked = tracked;

  % As a bonus we return the raw eye pose vectors, given that we have them anyway:
  result.rawEyePose7{1} = eyePose{1};
  result.rawEyePose7{2} = eyePose{2};

  % Want matrices which take a usercode supplied global transformation into account?
  if bitand(reqmask, 1)
    % Yes: We need tracked + predicted head pose, so we can apply the user transform,
    % and then per-eye transforms:

    % Get predicted head pose for targetTime:
    state = PsychOculusVRCore('GetTrackingState', myhmd.handle, targetTime);

    % Bonus feature: HeadPose as 7 component translation + orientation quaternion vector:
    result.headPose = state.HeadPose;

    % Convert head pose vector to 4x4 OpenGL right handed reference frame matrix:
    result.localHeadPoseMatrix = eyePoseToCameraMatrix(state.HeadPose);

    % Premultiply usercode provided global transformation matrix:
    result.globalHeadPoseMatrix = userTransformMatrix * result.localHeadPoseMatrix;

    % Compute per-eye global pose matrices:
    result.cameraView{1} = result.globalHeadPoseMatrix * hmd{myhmd.handle}.eyeShiftMatrix{1};
    result.cameraView{2} = result.globalHeadPoseMatrix * hmd{myhmd.handle}.eyeShiftMatrix{2};

    % Compute inverse matrices, useable as OpenGL GL_MODELVIEW matrices for rendering:
    result.modelView{1} = inv(result.cameraView{1});
    result.modelView{2} = inv(result.cameraView{2});
  end

  varargout{1} = result;

  return;
end

if strcmpi(cmd, 'GetEyePose')
  % Get and validate handle - fast path open coded:
  myhmd = varargin{1};
  if ~((length(hmd) >= myhmd.handle) && (myhmd.handle > 0) && hmd{myhmd.handle}.open)
    error('PsychOculusVR:GetEyePose: Specified handle does not correspond to an open HMD!');
  end

  % Valid: Get view render pass for which to return information:
  if length(varargin) < 2 || isempty(varargin{2})
    error('PsychOculusVR:GetEyePose: Required ''renderPass'' argument missing.');
  end
  renderPass = varargin{2};

  % Get 'userTransformMatrix' if any:
  if length(varargin) >= 3 && ~isempty(varargin{3})
    userTransformMatrix = varargin{3};
  else
    % Default: Identity transform to do nothing:
    userTransformMatrix = diag([1 1 1 1]);
  end

  % Get target time for predicted camera poses, head poses etc.:
  % NOTE: Currently not used, as Oculus SDK 0.5 does not support passing
  % targetTime into the underlying SDK function for 'GetEyePose'. The
  % Oculus runtime predicts something meaningful internally.
  %
  %  if length(varargin) >= 4 && ~isempty(varargin{4})
  %    targetTime = varargin{4};
  %  else
  %    % Default: Provide predicted value for the midpoint of the next video
  %    % refresh cycle - assuming we hit the flip deadline for the next video
  %    % frame, so that point in time will be exactly in the middle of both
  %    % eyes:
  %    winfo = Screen('GetWindowInfo', hmd{myhmd.handle}.win);
  %    targetTime = winfo.LastVBLTime + 1.5 * hmd{myhmd.handle}.videoRefreshDuration;
  %  end

  % Get eye pose for this renderPass, or more exactly the headPose from which this
  % renderPass eyePose will get computed:
  [result.headPose, result.eyeIndex] = PsychOculusVRCore('GetEyePose', myhmd.handle, renderPass);

  % Convert head pose vector to 4x4 OpenGL right handed reference frame matrix:
  result.localHeadPoseMatrix = eyePoseToCameraMatrix(result.headPose);

  % Premultiply usercode provided global transformation matrix:
  result.globalHeadPoseMatrix = userTransformMatrix * result.localHeadPoseMatrix;

  % Compute per-eye global pose matrix for this eyeIndex:
  result.cameraView = result.globalHeadPoseMatrix * hmd{myhmd.handle}.eyeShiftMatrix{result.eyeIndex + 1};

  % Compute inverse matrix, useable as OpenGL GL_MODELVIEW matrix for rendering:
  result.modelView = inv(result.cameraView);

  varargout{1} = result;

  return;
end

if strcmpi(cmd, 'Supported')
  % Check if the Oculus VR runtime is supported and active on this
  % installation, so it can be used to open connections to real HMDs,
  % or at least to emulate a HMD for simple debugging purposes:
  if exist('PsychOculusVRCore', 'file') && PsychOculusVRCore('GetCount') >= 0
    varargout{1} = 1;
  else
    varargout{1} = 0;
  end
  return;
end

% Autodetect first connected HMD and open a connection to it. Open a
% emulated one, if none can be detected. Perform basic setup with
% default configuration, create a proper PsychImaging task.
if strcmpi(cmd, 'AutoSetupHMD')
  % Do we have basic runtime support?
  if ~PsychOculusVR('Supported')
    % Nope: Game over.
    fprintf('PsychOculusVR:AutoSetupHMD: Could not initialize Oculus driver. Game over!\n');

    % Return an empty handle to signal lack of VR HMD support to caller,
    % so caller can cope with it somehow:
    varargout{1} = [];
    return;
  end

  % Basic task this HMD should fulfill:
  if length(varargin) >= 1 && ~isempty(varargin{1})
    basicTask = varargin{1};
  else
    basicTask = 'Tracked3DVR';
  end

  % Basic basicRequirements to choose:
  if length(varargin) >= 2 && ~isempty(varargin{2})
    basicRequirements = varargin{2};
  else
    basicRequirements = '';
  end

  % Basic quality/performance tradeoff to choose:
  if length(varargin) >= 3 && ~isempty(varargin{3})
    basicQuality = varargin{3};
  else
    basicQuality = 0;
  end

  % HMD device selection:
  if length(varargin) >= 4 && ~isempty(varargin{4})
    deviceIndex = varargin{4};
    newhmd = PsychOculusVR('Open', deviceIndex);
  else
    % Check if at least one Oculus HMD is connected and available:
    if PsychOculusVR('GetCount') > 0
      % Yes. Open and initialize connection to first detected HMD:
      fprintf('PsychOculusVR: Opening the first connected Oculus VR headset.\n');
      newhmd = PsychOculusVR('Open', 0);
    else
      % No. Open an emulated/simulated HMD for basic testing and debugging:
      fprintf('PsychOculusVR: No Oculus HMD detected. Opening a simulated HMD.\n');
      newhmd = PsychOculusVR('Open', -1);
    end
  end

  % Trigger an automatic device close at onscreen window close for the HMD display window:
  PsychOculusVR('SetAutoClose', newhmd, 1);

  % Setup default rendering parameters:
  PsychOculusVR('SetupRenderingParameters', newhmd, basicTask, basicRequirements, basicQuality);

  % Add a PsychImaging task to use this HMD with the next opened onscreen window:
  PsychImaging('AddTask', 'General', 'UseVRHMD', newhmd);

  % Return the device handle:
  varargout{1} = newhmd;

  % Ready.
  return;
end

if strcmpi(cmd, 'SetAutoClose')
  myhmd = varargin{1};

  if ~PsychOculusVR('IsOpen', myhmd)
    error('PsychOculusVR:SetAutoClose: Specified handle does not correspond to an open HMD!');
  end

  % Assign autoclose flag:
  hmd{myhmd.handle}.autoclose = varargin{2};

  return;
end

if strcmpi(cmd, 'SetHSWDisplayDismiss')
  myhmd = varargin{1};

  if ~PsychOculusVR('IsOpen', myhmd)
    error('PsychOculusVR:SetHSWDisplay: Specified handle does not correspond to an open HMD!');
  end

  % Method of dismissing HSW display:
  if length(varargin) < 2 || isempty(varargin{2})
    % Default is keyboard, mouse click, or HMD tap:
    hmd{myhmd.handle}.hswdismiss = 1 + 2 + 4;
  else
    hmd{myhmd.handle}.hswdismiss = varargin{2};
  end

  return;
end

% Open a HMD:
if strcmpi(cmd, 'Open')
  % Hack to make sure the VR runtime detects the HMD on a secondary X-Screen:
  if IsLinux && ~IsWayland && length(Screen('Screens')) > 1
    olddisp = getenv('DISPLAY');
    setenv('DISPLAY', sprintf(':0.%i', max(Screen('Screens'))));
  end

  [handle, modelName] = PsychOculusVRCore('Open', varargin{:});

  % Restore DISPLAY for other clients, e.g., Octave's gnuplot et al.:
  if exist('olddisp', 'var')
    setenv('DISPLAY', olddisp);
  end

  newhmd.handle = handle;
  newhmd.driver = @PsychOculusVR;
  newhmd.type   = 'Oculus';
  newhmd.open = 1;
  newhmd.modelName = modelName;
  newhmd.separateEyePosesSupported = 1;

  % Default autoclose flag to "no autoclose":
  newhmd.autoclose = 0;

  % Default to no use of timewarp:
  newhmd.useTimeWarp = 0;
  newhmd.readyForWarp = 0;

  % Default to no use of pixel luminance overdrive:
  newhmd.useOverdrive = 0;
  newhmd.lastOverdriveTex = -1;

  % Assign default overdrive contrast scale factors for rising
  % (UpScale) and falling (DownScale) pixel color component
  % intensities wrt. previous rendered frame:
  newhmd.overdriveUpScale   = 0.10;
  newhmd.overdriveDownScale = 0.05;

  % Perform a gamma / degamma pass on color values for a
  % gamma correction of 2.2 (hard-coded in the shader) by
  % default.
  %
  % Overdrive is optimized to operate in gamma space. As
  % we normally render and process in linear space, we
  % need to convert linear -> gamma -> Overdrive -> linear.
  % A setting of 0 for overdriveGammaCorrect would disable
  % gamma->degamma and operate purely linear:
  newhmd.overdriveGammaCorrect = 1;

  % By default allow user to dismiss HSW display via key press,
  % mouse click, or HMD tap:
  newhmd.hswdismiss = 1 + 2 + 4;

  % Setup basic task/requirement/quality specs to "nothing":
  newhmd.basicQuality = 0;
  newhmd.basicTask = '';
  newhmd.basicRequirements = '';

  % Store in internal array:
  hmd{handle} = newhmd;

  % Return device struct:
  varargout{1} = newhmd;
  varargout{2} = modelName;

  return;
end

if strcmpi(cmd, 'IsOpen')
  myhmd = varargin{1};
  if (length(hmd) >= myhmd.handle) && (myhmd.handle > 0) && hmd{myhmd.handle}.open
    varargout{1} = 1;
  else
    varargout{1} = 0;
  end
  return;
end

if strcmpi(cmd, 'GetInfo')
  % Ok, cheap trick: We just return the passed in 'hmd' struct - the up to date
  % internal copy that is:
  if ~PsychOculusVR('IsOpen', varargin{1})
    error('GetInfo: Passed in handle does not refer to a valid and open HMD.');
  end

  myhmd = varargin{1};
  varargout{1} = hmd{myhmd.handle};

  return;
end

if strcmpi(cmd, 'Close')
  if ~isempty(varargin) && ~isempty(varargin{1})
    % Close a specific hmd device:
    myhmd = varargin{1};

    % This function can be called with the raw index handle by
    % the autoclose code path. In that case, map index back into
    % full handle struct:
    if ~isstruct(myhmd)
      if length(hmd) >= myhmd
        myhmd = hmd{myhmd};
      else
        return;
      end
    end

    if (length(hmd) >= myhmd.handle) && (myhmd.handle > 0) && hmd{myhmd.handle}.open
      PsychOculusVRCore('Close', myhmd.handle);
      hmd{myhmd.handle}.open = 0;
    end
  else
    % Shutdown whole driver:
    PsychOculusVRCore('Close');
    hmd = [];
  end

  return;
end

if strcmpi(cmd, 'IsHMDOutput')
  myhmd = varargin{1}; %#ok<NASGU>
  scanout = varargin{2};

  % Is this a Rift DK2 panel?
  if (scanout.width == 1080) && (scanout.height == 1920)
    varargout{1} = 1;
  else
    varargout{1} = 0;
  end
  return;
end

if strcmpi(cmd, 'SetBasicQuality')
  myhmd = varargin{1};
  handle = myhmd.handle;
  basicQuality = varargin{2};
  basicQuality = min(max(basicQuality, 0), 1);
  hmd{handle}.basicQuality = basicQuality;

  if ~isempty(strfind(hmd{handle}.basicRequirements, 'FastResponse'))
    hmd{handle}.useOverdrive = 1;
  else
    % Overdrive off by default because expensive:
    hmd{handle}.useOverdrive = 0;
  end

  if ~isempty(strfind(hmd{handle}.basicRequirements, 'TimeWarp'))
    if basicQuality >= 0.5
      hmd{handle}.useTimeWarp = 2;
    else
      hmd{handle}.useTimeWarp = 1;
    end
  else
    % TimeWarp is off by default:
    hmd{handle}.useTimeWarp = 0;
  end

  if ~isempty(strfind(hmd{handle}.basicRequirements, 'LowPersistence'))
    PsychOculusVRCore('SetLowPersistence', handle, 1);
  else
    PsychOculusVRCore('SetLowPersistence', handle, 0);
  end

  % Dynamic prediction enables the DK2 latency tester, advanced head tracking
  % prediction and eye timewarping:
  if ~isempty(strfind(hmd{handle}.basicRequirements, 'TimingSupport')) || ...
     hmd{handle}.useTimeWarp || ~isempty(strfind(hmd{handle}.basicTask, 'Tracked3DVR'))
    PsychOculusVRCore('SetDynamicPrediction', handle, 1);
  else
    PsychOculusVRCore('SetDynamicPrediction', handle, 0);
  end

  return;
end

if strcmpi(cmd, 'SetFastResponse')
  myhmd = varargin{1};
  if ~PsychOculusVR('IsOpen', myhmd)
    error('SetFastResponse: Passed in handle does not refer to a valid and open HMD.');
  end

  % FastResponse determines use of GPU accelerated panel overdrive
  % on the Rift DK1/DK2. Return old setting:
  varargout{1} = hmd{myhmd.handle}.useOverdrive;

  % New setting requested?
  if (length(varargin) >= 2) && ~isempty(varargin{2})
    % Check if an enable is requested, and if so, if the neccessary prep work
    % has been done during AutoSetupHMD / SetupRenderingParameters  etc. at
    % startup:
    if (varargin{2} > 0)  && (hmd{myhmd.handle}.lastOverdriveTex < 0)
      error('SetFastResponse: Tried to enable fast response mode, but feature has not been requested during initial HMD setup, as required.');
    end

    % All good. Can select the new overdrive mode:
    hmd{myhmd.handle}.useOverdrive = varargin{2};
    handle = myhmd.handle;

    % Set new overdrive parameters for shaders:
    if varargin{2} > 0
      overdriveUpScale = hmd{handle}.overdriveUpScale;
      overdriveDownScale = hmd{handle}.overdriveDownScale;
      overdriveGammaCorrect = hmd{handle}.overdriveGammaCorrect;
    else
      overdriveUpScale = 0;
      overdriveDownScale = 0;
      overdriveGammaCorrect = 0;
    end

    glUseProgram(hmd{handle}.shaderLeft(1));
    glUniform3f(glGetUniformLocation(hmd{handle}.shaderLeft(1), 'OverdriveScales'), overdriveUpScale, overdriveDownScale, overdriveGammaCorrect);
    glUseProgram(hmd{handle}.shaderRight(1));
    glUniform3f(glGetUniformLocation(hmd{handle}.shaderRight(1), 'OverdriveScales'), overdriveUpScale, overdriveDownScale, overdriveGammaCorrect);
    glUseProgram(0);
  end

  return;
end

if strcmpi(cmd, 'SetTimeWarp')
  myhmd = varargin{1};
  if ~PsychOculusVR('IsOpen', myhmd)
    error('SetTimeWarp: Passed in handle does not refer to a valid and open HMD.');
  end

  % SetTimeWarp determines use of GPU accelerated 2D texture sampling
  % warp on the Rift DK1/DK2. Return old setting:
  varargout{1} = hmd{myhmd.handle}.useTimeWarp;

  % New setting requested?
  if (length(varargin) >= 2) && ~isempty(varargin{2})
    % Check if an enable is requested, and if so, if the neccessary prep work
    % has been done during AutoSetupHMD / SetupRenderingParameters  etc. at
    % startup:
    if (varargin{2} > 0)  && ~hmd{myhmd.handle}.readyForWarp
      error('SetTimeWarp: Tried to enable eye timewarp mode, but feature has not been requested during initial HMD setup, as required.');
    end

    % TimeWarp transition from enabled to disabled?
    if (varargin{2} <= 0) && (hmd{myhmd.handle}.useTimeWarp > 0)
      % Need to reset shaders matrices to identity matrices:
      handle = myhmd.handle;

      % Setup left shaders warp matrices:
      glUseProgram(hmd{handle}.shaderLeft(1));
      hmd{handle}.eyeRotStartMatrixLeft = diag([1 1 1 1]);
      hmd{handle}.eyeRotEndMatrixLeft   = diag([1 1 1 1]);
      glUniformMatrix4fv(hmd{handle}.shaderLeft(2), 1, 1, hmd{handle}.eyeRotStartMatrixLeft);
      glUniformMatrix4fv(hmd{handle}.shaderLeft(3), 1, 1, hmd{handle}.eyeRotEndMatrixLeft);

      % Setup right shaders warp matrices:
      glUseProgram(hmd{handle}.shaderRight(1));
      hmd{handle}.eyeRotStartMatrixRight = diag([1 1 1 1]);
      hmd{handle}.eyeRotEndMatrixRight   = diag([1 1 1 1]);
      glUniformMatrix4fv(hmd{handle}.shaderRight(2), 1, 1, hmd{handle}.eyeRotStartMatrixRight);
      glUniformMatrix4fv(hmd{handle}.shaderRight(3), 1, 1, hmd{handle}.eyeRotEndMatrixRight);
      glUseProgram(0);
    end

    % All good. Can select the new timeWarp mode:
    hmd{myhmd.handle}.useTimeWarp = varargin{2};
  end

  return;
end

if strcmpi(cmd, 'SetLowPersistence')
  myhmd = varargin{1};
  if ~PsychOculusVR('IsOpen', myhmd)
    error('SetLowPersistence: Passed in handle does not refer to a valid and open HMD.');
  end

  % SetLowPersistence determines use low persistence mode on the Rift DK2. Return old setting:
  varargout{1} = PsychOculusVRCore('SetLowPersistence', myhmd.handle);

  % New setting requested?
  if (length(varargin) >= 2) && ~isempty(varargin{2})
    PsychOculusVRCore('SetLowPersistence', myhmd.handle, varargin{2});
  end

  return;
end

if strcmpi(cmd, 'SetupRenderingParameters')
  myhmd = varargin{1};

  % Basic task this HMD should fulfill:
  if length(varargin) >= 2 && ~isempty(varargin{2})
    basicTask = varargin{2};
  else
    basicTask = 'Tracked3DVR';
  end

  % Basic requirements to choose:
  if length(varargin) >= 3 && ~isempty(varargin{3})
    basicRequirements = varargin{3};
  else
    basicRequirements = '';
  end

  % Basic quality/performance tradeoff to choose:
  if length(varargin) >= 4 && ~isempty(varargin{4})
    basicQuality = varargin{4};
  else
    basicQuality = 0;
  end

  hmd{myhmd.handle}.basicTask = basicTask;
  hmd{myhmd.handle}.basicRequirements = basicRequirements;

  PsychOculusVR('SetBasicQuality', myhmd, basicQuality);

  % Get optimal client renderbuffer size - the size of our virtual framebuffer for left eye:
  [hmd{myhmd.handle}.rbwidth, hmd{myhmd.handle}.rbheight, hmd{myhmd.handle}.fov] = PsychOculusVRCore('GetFovTextureSize', myhmd.handle, 0, varargin{5:end});

  % Get optimal client renderbuffer size - the size of our virtual framebuffer for right eye:
  [hmd{myhmd.handle}.rbwidth, hmd{myhmd.handle}.rbheight, hmd{myhmd.handle}.fov] = PsychOculusVRCore('GetFovTextureSize', myhmd.handle, 1, varargin{5:end});

  return;
end

if strcmpi(cmd, 'GetClientRenderingParameters')
  myhmd = varargin{1};
  varargout{1} = [hmd{myhmd.handle}.rbwidth, hmd{myhmd.handle}.rbheight];

  % We need fast backing store support for virtual framebuffers:
  imagingMode = mor(kPsychNeedTwiceWidthWindow, kPsychNeedFastBackingStore);
  imagingMode = mor(imagingMode, kPsychNeedClientRectNoFitter);

  % Need an output FBO for our panel overdrive implementation:
  if hmd{myhmd.handle}.useOverdrive || strcmpi(hmd{myhmd.handle}.basicTask, 'Monoscopic')
    imagingMode = mor(imagingMode, kPsychNeedOutputConversion);
  end

  if ~strcmpi(hmd{myhmd.handle}.basicTask, 'Monoscopic')
    % We must use stereomode 6, so we get separate draw buffers for left and
    % right eye, and the stereo compositor (merger) to fuse both eyes into a
    % single output framebuffer, but with all internal buffers at at least
    % full output framebuffer resolution. This will generate anaglyph shaders
    % which we will need to replace with a very special shader for the HMD:
    stereoMode = 6;
  else
    % Monoscopic presentation will do:
    stereoMode = 0;
  end

  varargout{2} = imagingMode;
  varargout{3} = stereoMode;
  return;
end

if strcmpi(cmd, 'GetEyeShiftVector')
  myhmd = varargin{1};

  if varargin{2} == 0
    varargout{1} = hmd{myhmd.handle}.HmdToEyeViewOffsetLeft;
    varargout{2} = hmd{myhmd.handle}.eyeShiftMatrix{1};
  else
    varargout{1} = hmd{myhmd.handle}.HmdToEyeViewOffsetRight;
    varargout{2} = hmd{myhmd.handle}.eyeShiftMatrix{2};
  end

  return;
end

if strcmpi(cmd, 'PerformPostWindowOpenSetup')

  % Must have global GL constants:
  if isempty(GL)
    varargout{1} = 0;
    warning('PTB internal error in PsychOculusVR: GL struct not initialized?!?');
    return;
  end

  % Oculus device handle:
  myhmd = varargin{1};
  handle = myhmd.handle;

  % Onscreen window handle:
  win = varargin{2};

  % Keep track of window handle of associated onscreen window:
  hmd{handle}.win = win;

  % Also keep track of video refresh duration of the HMD:
  hmd{handle}.videoRefreshDuration = Screen('Framerate', win);
  if hmd{handle}.videoRefreshDuration == 0
    % Unlikely to ever hit this situation, but if we would, just
    % default to the Rift DK-2's default video refresh rate of 75 Hz:
    hmd{handle}.videoRefreshDuration = 75;
  end
  hmd{handle}.videoRefreshDuration = 1 / hmd{handle}.videoRefreshDuration;

  % Compute effective size of per-eye input buffer for undistortion render.
  % The input buffers for undistortion are the processedDrawbufferFBO's aka
  % inputBufferFBO's, or if the panelfitter is skipped the drawBufferFBO's.
  %
  % In our current implementation we allocate said buffers to twice the horizontal
  % size of the real framebuffer, ie., twice the panel width of the HMD, as
  % that should be plenty for all typical use cases - and is also the maximum
  % possible with the current Screen imaging pipeline.
  %
  % However, we don't use the full size of those buffers as input, but only
  % sample a rectangular subregion which corresponds to the renderbuffer size
  % recommended by the Oculus runtime. Either the panelfitter is used to blit
  % 1-to-1 from the drawBufferFBO to a correspondingly sized subregion of the
  % inputBuffers - if the panelfitter is needed for convenient 2D stimulus drawing
  % or MSAA resolve - or usercode has to restrict its rendering to the subregion by
  % proper use of glViewPorts or scissor rectangles.
  %
  % So for all practical means [inputWidth, inputHeight] == [rbwidth, rbheight] and
  % we save processing bandwidth, although due to the overallocation not VRAM memory
  % space.
  hmd{handle}.inputWidth = hmd{handle}.rbwidth;
  hmd{handle}.inputHeight = hmd{handle}.rbheight;

  % Query undistortion parameters for left eye view:
  [hmd{handle}.rbwidth, hmd{handle}.rbheight, vx, vy, vw, vh, ptx, pty, hsx, hsy, hsz, meshVL, meshIL, uvScale(1), uvScale(2), uvOffset(1), uvOffset(2)] = PsychOculusVRCore('GetUndistortionParameters', handle, 0, hmd{handle}.inputWidth, hmd{handle}.inputHeight, hmd{handle}.fov);
  hmd{handle}.viewportLeft = [vx, vy, vw, vh];
  hmd{handle}.PixelsPerTanAngleAtCenterLeft = [ptx, pty];
  hmd{handle}.HmdToEyeViewOffsetLeft = -1 * [hsx, hsy, hsz];
  hmd{handle}.meshVerticesLeft = meshVL;
  hmd{handle}.meshIndicesLeft = meshIL;
  hmd{handle}.uvScaleLeft = uvScale;
  hmd{handle}.uvOffsetLeft = uvOffset;

  % Init warp matrices to identity, until we get something better from live tracking:
  hmd{handle}.eyeRotStartMatrixLeft = diag([1 1 1 1]);
  hmd{handle}.eyeRotEndMatrixLeft   = diag([1 1 1 1]);

  % Query parameters for right eye view:
  [hmd{handle}.rbwidth, hmd{handle}.rbheight, vx, vy, vw, vh, ptx, pty, hsx, hsy, hsz, meshVR, meshIR, uvScale(1), uvScale(2), uvOffset(1), uvOffset(2)] = PsychOculusVRCore('GetUndistortionParameters', handle, 1, hmd{handle}.inputWidth, hmd{handle}.inputHeight, hmd{handle}.fov);
  hmd{handle}.viewportRight = [vx, vy, vw, vh];
  hmd{handle}.PixelsPerTanAngleAtCenterRight = [ptx, pty];
  hmd{handle}.HmdToEyeViewOffsetRight = -1 * [hsx, hsy, hsz];
  hmd{handle}.meshVerticesRight = meshVR;
  hmd{handle}.meshIndicesRight = meshIR;
  hmd{handle}.uvScaleRight = uvScale;
  hmd{handle}.uvOffsetRight = uvOffset;

  % Init warp matrices to identity, until we get something better from live tracking:
  hmd{handle}.eyeRotStartMatrixRight = diag([1 1 1 1]);
  hmd{handle}.eyeRotEndMatrixRight   = diag([1 1 1 1]);

  % Convert head to eye shift vectors into 4x4 matrices, as we'll need
  % them frequently:
  EyeT = diag([1 1 1 1]);
  EyeT(1:3, 4) = hmd{handle}.HmdToEyeViewOffsetLeft';
  hmd{handle}.eyeShiftMatrix{1} = EyeT;

  EyeT = diag([1 1 1 1]);
  EyeT(1:3, 4) = hmd{handle}.HmdToEyeViewOffsetRight';
  hmd{handle}.eyeShiftMatrix{2} = EyeT;

  % Assign proper target processing chain for imaging pipeline:
  if ~strcmpi(hmd{handle}.basicTask, 'Monoscopic')
    % Stereoscopic display: Stereo composer chain.
    procchain = 'StereoCompositingBlit';

    % Find slot with preexisting stereo composition shader, so we can replace it by our thing:
    [slot, shaderid, blittercfg, voidptr, glsl] = Screen('HookFunction', win, 'Query', procchain, 'StereoCompositingShaderAnaglyph'); %#ok<ASGLU>
    if slot == -1
      varargout{1} = 0;
      warning('Either the imaging pipeline is not enabled for given onscreen window, or it is not switched to Anaglyph stereo mode.');
      return;
    end

    if glsl == 0
      varargout{1} = 0;
      warning('Anaglyph shader is not operational for unknown reason. Sorry...');
      return;
    end

    % Remove old standard anaglyph shader:
    Screen('HookFunction', win, 'Remove', procchain, slot);
  else
    % Monoscopic display: Final output formatter:
    procchain = 'FinalOutputFormattingBlit';
    Screen('HookFunction', win, 'Enable', procchain);
    slot = 0;
    glsl = 0;
  end

  % Build the unwarp mesh display list within the OpenGL context of Screen():
  Screen('BeginOpenGL', win, 1);

  % Left eye setup:
  % ---------------

  % Build a display list that corresponds to the current calibration,
  % drawing the warp-mesh once, so it gets recorded in the display list:
  gldLeft = glGenLists(1);
  glNewList(gldLeft, GL.COMPILE);

  % Caution: Must *copy* the different rows with data into *separate* variables, so
  % the vertex array pointers to the different variables actually point to something
  % persistent! If we'd pass the meshVerticesLeft() subarrays directly to glTexCoordPointer
  % and friends then Octave/Matlab would just create a temporary copy of the extracted
  % rows, OpenGL would retrieve/assign pointers to those temporary copies, but then
  % at the end of a glVertexPointer/glTexCoordPointer call, those temporary copies would
  % go out of scope and Octave/Matlab would potentially garbage collect the variables again
  % *before* the call to glDrawElements permanently records the content of the variables.
  % The net results would be stale/dangling pointers, random data trash getting read from
  % memory and recorded in the display list - and thereby corrupted rendering! This hazard
  % doesn't exist within regular Octave/Matlab scripts, because the interpreter doesn't
  % deal with memory pointers. It is a unique hazard from the combination of C memory
  % pointers for OpenGL and Octave/Matlabs copy-on-write/data-sharing/garbage collection
  % behaviour. When we are at it, lets also cast the data to single() precision floating
  % point, to save some memory:
  vertexpos = single(hmd{handle}.meshVerticesLeft(1:4, :));

  if ~IsLinux
      % Both Windows and OSX need special treatment, because the 0.5 SDK
      % doesn't generate a properly rotated undistortion mesh. Rotate
      % vertex (x,y) positions by 90 degrees counter-clockwise, so the mesh
      % aligns with the 90 degrees rotated full HD panel of the Rift DK-1
      % and DK-2. This allows to keep the video mode on at, e.g. for the
      % DK-2, native 1080 x 1920 without enabling output rotation. That in
      % turn keeps page flipping enabled for bufferswaps, at least on the
      % non-broken graphics drivers, and that in turn keeps PTB's timing
      % happy and performance up:
      R = single([0, -1 ; 1, 0]);
      vertexpos(1:2, :) = R * vertexpos(1:2, :);
  end

  texR = single(hmd{handle}.meshVerticesLeft(5:6, :));
  texG = single(hmd{handle}.meshVerticesLeft(7:8, :));
  texB = single(hmd{handle}.meshVerticesLeft(9:10, :));

  % vertex xy encodes 2D position from rows 1 and 2, z encodes timeWarp interpolation factors
  % from row 3 and w encodes vignette correction factors from row 4:
  glEnableClientState(GL.VERTEX_ARRAY);
  glVertexPointer(4, GL.FLOAT, 0, vertexpos);

  % Need separate texture coordinate sets for the three color channel to encode
  % channel specific color aberration correction sampling:

  % TexCoord set 0 encodes coordinates for the Red color channel:
  glClientActiveTexture(GL.TEXTURE0);
  glEnableClientState(GL.TEXTURE_COORD_ARRAY);
  glTexCoordPointer(2, GL.FLOAT, 0, texR);
  
  % TexCoord set 1 encodes coordinates for the Green color channel:
  glClientActiveTexture(GL.TEXTURE1);
  glEnableClientState(GL.TEXTURE_COORD_ARRAY);
  glTexCoordPointer(2, GL.FLOAT, 0, texG);

  % TexCoord set 2 encodes coordinates for the Blue color channel:
  glClientActiveTexture(GL.TEXTURE2);
  glEnableClientState(GL.TEXTURE_COORD_ARRAY);
  glTexCoordPointer(2, GL.FLOAT, 0, texB);

  % Draw the mesh. This records the content from all the variables persistently into
  % the display list storage, so they can be freed afterwards:
  glDrawElements(GL.TRIANGLES, length(hmd{handle}.meshIndicesLeft), GL.UNSIGNED_SHORT, uint16(hmd{handle}.meshIndicesLeft));

  % Disable stuff, so we can release or recycle the variables:
  glClientActiveTexture(GL.TEXTURE3);
  glDisableClientState(GL.TEXTURE_COORD_ARRAY);

  glClientActiveTexture(GL.TEXTURE2);
  glDisableClientState(GL.TEXTURE_COORD_ARRAY);

  glClientActiveTexture(GL.TEXTURE1);
  glDisableClientState(GL.TEXTURE_COORD_ARRAY);

  glClientActiveTexture(GL.TEXTURE0);
  glDisableClientState(GL.TEXTURE_COORD_ARRAY);

  glDisableClientState(GL.VERTEX_ARRAY);
  
  % Left eye display list done.
  glEndList;

  % Right eye setup:
  % ---------------

  % Build a display list that corresponds to the current calibration,
  % drawing the warp-mesh once, so it gets recorded in the display list:
  gldRight = glGenLists(1);
  glNewList(gldRight, GL.COMPILE);

  vertexpos = single(hmd{handle}.meshVerticesRight(1:4, :));

  if ~IsLinux
      % Same special treatment on non-Linux as for the left eye. Rotate mesh by
      % 90 degrees counter-clockwise:
      vertexpos(1:2, :) = R * vertexpos(1:2, :);
  end

  texR = single(hmd{handle}.meshVerticesRight(5:6, :));
  texG = single(hmd{handle}.meshVerticesRight(7:8, :));
  texB = single(hmd{handle}.meshVerticesRight(9:10, :));

  % vertex xy encodes 2D position from rows 1 and 2, z encodes timeWarp interpolation factors
  % from row 3 and w encodes vignette correction factors from row 4:
  glEnableClientState(GL.VERTEX_ARRAY);
  glVertexPointer(4, GL.FLOAT, 0, vertexpos);

  % Need separate texture coordinate sets for the three color channel to encode
  % channel specific color aberration correction sampling:

  % TexCoord set 0 encodes coordinates for the Red color channel:
  glClientActiveTexture(GL.TEXTURE0);
  glEnableClientState(GL.TEXTURE_COORD_ARRAY);
  glTexCoordPointer(2, GL.FLOAT, 0, texR);
  
  % TexCoord set 1 encodes coordinates for the Green color channel:
  glClientActiveTexture(GL.TEXTURE1);
  glEnableClientState(GL.TEXTURE_COORD_ARRAY);
  glTexCoordPointer(2, GL.FLOAT, 0, texG);

  % TexCoord set 2 encodes coordinates for the Blue color channel:
  glClientActiveTexture(GL.TEXTURE2);
  glEnableClientState(GL.TEXTURE_COORD_ARRAY);
  glTexCoordPointer(2, GL.FLOAT, 0, texB);

  % Draw the mesh. This records the content from all the variables persistently into
  % the display list storage, so they can be freed afterwards:
  glDrawElements(GL.TRIANGLES, length(hmd{handle}.meshIndicesRight), GL.UNSIGNED_SHORT, uint16(hmd{handle}.meshIndicesRight));

  % Disable stuff, so we can release or recycle the variables:
  glClientActiveTexture(GL.TEXTURE3);
  glDisableClientState(GL.TEXTURE_COORD_ARRAY);

  glClientActiveTexture(GL.TEXTURE2);
  glDisableClientState(GL.TEXTURE_COORD_ARRAY);

  glClientActiveTexture(GL.TEXTURE1);
  glDisableClientState(GL.TEXTURE_COORD_ARRAY);

  glClientActiveTexture(GL.TEXTURE0);
  glDisableClientState(GL.TEXTURE_COORD_ARRAY);

  glDisableClientState(GL.VERTEX_ARRAY);
  
  % Right eye display list done.
  glEndList;

  Screen('EndOpenGL', win);

  if hmd{handle}.useOverdrive
    % Overdrive enabled: Assign overdrive contrast scale factors for
    % rising (UpScale) and falling (DownScale) pixel color component
    % intensities wrt. previous rendered frame:
    overdriveUpScale = hmd{handle}.overdriveUpScale;
    overdriveDownScale = hmd{handle}.overdriveDownScale;

    % Perform a gamma / degamma pass on color values for a
    % gamma correction of 2.2 (hard-coded in the shader).
    % Overdrive is optimized to operate in gamma space. As
    % we normally render and process in linear space, we
    % need to convert linear -> gamma -> Overdrive -> linear.
    % A setting of 0 for overdriveGammaCorrect would disable
    % gamma->degamma and operate purely linear:
    overdriveGammaCorrect = hmd{handle}.overdriveGammaCorrect;
  else
    % Overdrive disabled:
    overdriveUpScale = 0;
    overdriveDownScale = 0;
    overdriveGammaCorrect = 0;
  end

  % Setup left eye shader:
  glsl = LoadGLSLProgramFromFiles('OculusRiftCorrectionShader');
  glUseProgram(glsl);
  glUniform1i(glGetUniformLocation(glsl, 'Image'), 0);
  glUniform1i(glGetUniformLocation(glsl, 'PrevImage'), 2);
  glUniform3f(glGetUniformLocation(glsl, 'OverdriveScales'), overdriveUpScale, overdriveDownScale, overdriveGammaCorrect);
  glUniform2f(glGetUniformLocation(glsl, 'EyeToSourceUVOffset'), hmd{handle}.uvOffsetLeft(1) * hmd{handle}.inputWidth, hmd{handle}.uvOffsetLeft(2) * hmd{handle}.inputHeight);
  glUniform2f(glGetUniformLocation(glsl, 'EyeToSourceUVScale'), hmd{handle}.uvScaleLeft(1) * hmd{handle}.inputWidth, hmd{handle}.uvScaleLeft(2) * hmd{handle}.inputHeight);
  glUniformMatrix4fv(glGetUniformLocation(glsl, 'EyeRotationStart'), 1, 1, hmd{handle}.eyeRotStartMatrixLeft);
  glUniformMatrix4fv(glGetUniformLocation(glsl, 'EyeRotationEnd'), 1, 1, hmd{handle}.eyeRotEndMatrixLeft);
  hmd{handle}.shaderLeft = [glsl, glGetUniformLocation(glsl, 'EyeRotationStart'), glGetUniformLocation(glsl, 'EyeRotationEnd')];
  glUseProgram(0);

  % Insert it at former position of the old shader:
  posstring = sprintf('InsertAt%iShader', slot);
  
  % xOffset and yOffset encode the viewport location and size for the left-eye vs.
  % right eye view in the shared output window - or the source renderbuffer if both eyes
  % would be rendered into a shared texture. However, the meshes provided by the SDK
  % already encode proper left and right offsets for output, and the inputs are separate
  % textures for left and right eye, so using the offset is not needed. Also our correction
  % shader ignores the modelview matrix which would get updated with the "Offset:%i%i" blittercfg,
  % instead is takes normalized device coordinates NDC directly from the distortion mesh. Iow, not
  % only is xOffset/yOffset not needed, it would also be a no operation due to our specific shader.
  % We leave this here for documentation for now, in case we need to change our ways of doing this.
  %leftViewPort = hmd{handle}.viewportLeft
  blittercfg = sprintf('Blitter:DisplayListBlit:Handle:%i:Bilinear', gldLeft);
  Screen('Hookfunction', win, posstring, procchain, 'OculusVRClientCompositingShaderLeftEye', glsl, blittercfg);

  % Setup right eye shader:
  glsl = LoadGLSLProgramFromFiles('OculusRiftCorrectionShader');
  glUseProgram(glsl);
  if ~strcmpi(hmd{handle}.basicTask, 'Monoscopic')
    % Stereoscopic display: Source from right eye buffer:
    glUniform1i(glGetUniformLocation(glsl, 'Image'), 1);
  else
    % Monoscopic display: Source right eye image also from left-eye (aka mono) buffer:
    glUniform1i(glGetUniformLocation(glsl, 'Image'), 0);
  end

  glUniform1i(glGetUniformLocation(glsl, 'PrevImage'), 2);
  glUniform3f(glGetUniformLocation(glsl, 'OverdriveScales'), overdriveUpScale, overdriveDownScale, overdriveGammaCorrect);
  glUniform2f(glGetUniformLocation(glsl, 'EyeToSourceUVOffset'), hmd{handle}.uvOffsetRight(1) * hmd{handle}.inputWidth, hmd{handle}.uvOffsetRight(2) * hmd{handle}.inputHeight);
  glUniform2f(glGetUniformLocation(glsl, 'EyeToSourceUVScale'), hmd{handle}.uvScaleRight(1) * hmd{handle}.inputWidth, hmd{handle}.uvScaleRight(2) * hmd{handle}.inputHeight);
  glUniformMatrix4fv(glGetUniformLocation(glsl, 'EyeRotationStart'), 1, 1, hmd{handle}.eyeRotStartMatrixRight);
  glUniformMatrix4fv(glGetUniformLocation(glsl, 'EyeRotationEnd'), 1, 1, hmd{handle}.eyeRotEndMatrixRight);
  hmd{handle}.shaderRight = [glsl, glGetUniformLocation(glsl, 'EyeRotationStart'), glGetUniformLocation(glsl, 'EyeRotationEnd')];
  glUseProgram(0);

  % Insert it at former position of the old shader:
  posstring = sprintf('InsertAt%iShader', slot);
  blittercfg = sprintf('Blitter:DisplayListBlit:Handle:%i:Bilinear', gldRight);
  Screen('Hookfunction', win, posstring, procchain, 'OculusVRClientCompositingShaderRightEye', glsl, blittercfg);

  % TimeWarp or panel overdrive in use?
  if hmd{handle}.useTimeWarp || hmd{handle}.useOverdrive
    % Need to call the PsychOculusVR(1) callback to do needed setup work:
    posstring = sprintf('InsertAt%iMFunction', slot);
    cmdString = sprintf('PsychOculusVR(1, %i);', handle);
    Screen('Hookfunction', win, posstring, procchain, 'OculusVRTimeWarpSetup', cmdString);
    hmd{handle}.readyForWarp = 1;
  end

  if hmd{handle}.useOverdrive
    if strcmpi(hmd{handle}.basicTask, 'Monoscopic')
      % Need a bufferflip command:
      Screen('HookFunction', win, 'AppendBuiltin', 'FinalOutputFormattingBlit', 'Builtin:FlipFBOs', '');
    end

    [realw, realh] = Screen('Windowsize', win, 1);
    Screen('HookFunction', win, 'AppendBuiltin', 'FinalOutputFormattingBlit', 'Builtin:IdentityBlit', sprintf('Blitter:IdentityBlit:OvrSize:%i:%i', realw, realh));
    Screen('HookFunction', win, 'Enable', 'FinalOutputFormattingBlit');

    woverdrive1 = Screen('OpenOffscreenwindow', win, [255 0 0], [0, 0, realw * 2, realh], [], 32);
    hmd{handle}.overdriveTex(1) = Screen('GetOpenGLTexture', woverdrive1, woverdrive1);
    woverdrive2 = Screen('OpenOffscreenwindow', win, [0 255 0], [0, 0, realw * 2, realh], [], 32);
    hmd{handle}.overdriveTex(2) = Screen('GetOpenGLTexture', woverdrive2, woverdrive2);
    hmd{handle}.lastOverdriveTex = 0;
  end

  % Need to call the PsychOculusVR(2) callback to do needed finalizer work:
  cmdString = sprintf('PsychOculusVR(2, %i);', handle);
  Screen('Hookfunction', win, 'AppendMFunction', 'LeftFinalizerBlitChain', 'OculusVRLatencyTesterSetup', cmdString);
  Screen('Hookfunction', win, 'Enable', 'LeftFinalizerBlitChain');

  % Need to call the end frame marker function of the Oculus runtime:
  cmdString = sprintf('PsychOculusVRCore(''EndFrameTiming'', %i);', handle);
  Screen('Hookfunction', win, 'PrependMFunction', 'ScreenFlipImpliedOperations', 'OculusVRPostPresentCallback', cmdString);
  Screen('Hookfunction', win, 'Enable', 'ScreenFlipImpliedOperations');

  % Does usercode request auto-closing the HMD or driver when the onscreen window is closed?
  if hmd{handle}.autoclose > 0
    % Attach a window close callback for Device teardown at window close time:
    if hmd{handle}.autoclose == 2
      % Shutdown driver completely:
      Screen('Hookfunction', win, 'AppendMFunction', 'CloseOnscreenWindowPostGLShutdown', 'Shutdown window callback into PsychOculusVR driver.', 'PsychOculusVR(''Close'');');
    else
      % Only close this HMD:
      Screen('Hookfunction', win, 'AppendMFunction', 'CloseOnscreenWindowPostGLShutdown', 'Shutdown window callback into PsychOculusVR driver.', sprintf('PsychOculusVR(''Close'', %i);', handle));
    end

    Screen('HookFunction', win, 'Enable', 'CloseOnscreenWindowPostGLShutdown');
  end

  % Need HSW display?
  if (hmd{handle}.hswdismiss >= 0) && isempty(getenv('PSYCH_OCULUS_HSWSKIP'))
    if IsWin
      % Windows doesn't distinguish keyboards, so don't query "all"
      % keyboards. This gives the same effect as on Linux/OSX, but avoids
      % use of PsychHID and potential "libusb not installed" warnings:
      kbddev = [];
    else
      kbddev = -1;
    end

    if bitand(hmd{myhmd.handle}.hswdismiss, 1)
      KbReleaseWait(kbddev);
    end

    dismiss = 0;
    if PsychOculusVRCore('GetHSWState', handle)
      % Yes: Display HSW text:
      hswtext = ['HEALTH & SAFETY WARNING\n\n' ...
                'Read and follow all warnings\n' ...
                'and instructions included with\n' ...
                'the Headset before use. Headset\n' ...
                'should be calibrated for each user.\n' ...
                'Not for use by children under 13.\n' ...
                'Stop use if you experience any\n' ...
                'discomfort or health reactions.\n\n' ...
                'More: www.oculus.com/warnings\n\n' ...
                'To acknowledge:\n'];

      if bitand(hmd{myhmd.handle}.hswdismiss, 1)
        hswtext = [hswtext 'Press a key\n'];
      end

      if bitand(hmd{myhmd.handle}.hswdismiss, 2)
        hswtext = [hswtext 'Click any mouse button\n'];
      end

      if bitand(hmd{myhmd.handle}.hswdismiss, 4)
        hswtext = [hswtext 'Slightly tap the headset'];
      end

      oldTextSize = Screen('TextSize', win, 16);
      Screen('SelectStereoDrawBuffer', win, 1);
      DrawFormattedText(win, hswtext, 'center', 'center', [0 255 0]);
      Screen('SelectStereoDrawBuffer', win, 0);
      DrawFormattedText(win, hswtext, 'center', 'center', [0 255 0]);
      Screen('TextSize', win, oldTextSize);
      Screen('Flip', win, [], 1);

      % Allow dismiss via tap to the HMD?
      if bitand(hmd{myhmd.handle}.hswdismiss, 4)
        % Enable tracking so we can allow user to dismiss HSW via a
        % slight tap to the HMD - accelerometers will do their thing:
        PsychOculusVRCore('Start', handle);
      end

      % Wait for dismiss via keypress, mouse button click or HMD tap:
      while PsychOculusVRCore('GetHSWState', handle, dismiss)
        % Allow dismiss via keypress?
        if bitand(hmd{myhmd.handle}.hswdismiss, 1) && KbCheck(kbddev)
          dismiss = 1;
        end

        % Allow dismiss via mouse click?
        if bitand(hmd{myhmd.handle}.hswdismiss, 2)
          [dummy1, dummy2, buttons] = GetMouse; %#ok<ASGLU>
          if any(buttons)
            dismiss = 1;
            while any(buttons)
              [dummy1, dummy2, buttons] = GetMouse; %#ok<ASGLU>
            end
          end
        end

        % Need to idle flip here to drive timewarp rendering in
        % case some stuff is enabled:
        Screen('Flip', win, [], 1);
      end

      if bitand(hmd{myhmd.handle}.hswdismiss, 1)
        KbReleaseWait(kbddev);
      end

      if bitand(hmd{myhmd.handle}.hswdismiss, 4)
        % Stop tracking for tap detection:
        PsychOculusVRCore('Stop', handle);
        WaitSecs(1);
      end

      % Clear HSW text:
      Screen('Flip', win);
    end
  end

  if ~isempty(strfind(hmd{myhmd.handle}.basicTask, 'Tracked3DVR'))
    % 3D head tracked VR rendering task: Start tracking as a convenience:
    PsychOculusVRCore('Start', handle);
  end

  % Return success result code 1:
  varargout{1} = 1;
  return;
end

% 'cmd' so far not dispatched? Let's assume it is a command
% meant for PsychOculusVRCore:
if (length(varargin) >= 1) && isstruct(varargin{1})
  myhmd = varargin{1};
  handle = myhmd.handle;
  [ varargout{1:nargout} ] = PsychOculusVRCore(cmd, handle, varargin{2:end});
else
  [ varargout{1:nargout} ] = PsychOculusVRCore(cmd, varargin{:});
end

return;

end
