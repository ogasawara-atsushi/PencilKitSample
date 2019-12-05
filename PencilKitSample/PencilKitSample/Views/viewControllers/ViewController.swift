import UIKit
import RxSwift
import RxCocoa

class ViewController: UIViewController {

    @IBOutlet weak private var showCanvasButton: UIButton!
    private var disposeBag = DisposeBag()

    override func viewDidLoad() {
        super.viewDidLoad()
        bind()
    }

    private func bind() {
        showCanvasButton.rx.tap.subscribe(onNext: { [unowned self] in
            let controller = CanvasPrototypeViewController.instantiate(draws: [Draw()])
            self.present(controller, animated: true, completion: nil)
        }).disposed(by: disposeBag)
    }
}

