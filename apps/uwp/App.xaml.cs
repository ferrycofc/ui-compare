using System;
using Windows.ApplicationModel.Activation;
using Windows.Foundation;
using Windows.UI.ViewManagement;
using Windows.UI.Xaml;
using Windows.UI.Xaml.Controls;

namespace NovaUWP
{
    sealed partial class App : Application
    {
        public App()
        {
            InitializeComponent();

            // 启动时的窗口大小（视图大小，不含系统标题栏），第一次启动生效
            ApplicationView.PreferredLaunchViewSize = new Size(906, 621);
            ApplicationView.PreferredLaunchWindowingMode = ApplicationViewWindowingMode.PreferredLaunchViewSize;
        }

        protected override void OnLaunched(LaunchActivatedEventArgs e)
        {
            var frame = Window.Current.Content as Frame;
            if (frame == null)
            {
                frame = new Frame();
                Window.Current.Content = frame;
            }

            if (frame.Content == null)
            {
                frame.Navigate(typeof(MainPage), e.Arguments);
            }

            Window.Current.Activate();
        }
    }
}
