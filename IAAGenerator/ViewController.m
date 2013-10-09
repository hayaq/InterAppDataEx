#import "ViewController.h"
#import "IAAGenerator.h"

@implementation ViewController{
	IAAGenerator *_iaaGenerator;
	IBOutlet UIImageView *_sendImage;
}

- (void)viewDidLoad{
    [super viewDidLoad];
	
	NSString *path = [[NSBundle mainBundle] pathForResource:@"test" ofType:@"png"];
	NSData *data = [NSData dataWithContentsOfFile:path];
	_iaaGenerator = [[IAAGenerator alloc] initWithData:data];
	
	_sendImage.image = [UIImage imageWithData:data];
}

@end
