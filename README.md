# creep

Researching anomaly detection via ML on syscall vectors.

### Background

This is an undergraduate senior research & exploration project. The motivations are interests in operating systems, security, and machine learning. As a novice and outsider to these areas, I'm ignorant to the State of The Art. I've learned that most of the ideas that follow are not new, and in fact this exact thing is a core feature of modern [EDR](https://en.wikipedia.org/wiki/Endpoint_detection_and_response).  

I'm on well-tread ground. I'll continue down the path since it's all still new to me.

### Objective
- Capture and alert on anomalous syscall behavior with ad-hoc tooling.

### Deliverables
Modules:
- Syscall capture
- ML model(s)
- Test and alert
- Presentation (glue)

### Scope & Limitations

- #### Process level capture.
    - Given time and training data constraints, the scope of this will be process level. 

- #### Training dataset is outdated.
    - The ADFA IDS training dataset may not reflect modern attacks.

- #### This is an ad-hoc toolset. 
    - This is intended to be an ad-hoc proof-of-concept toolset. See the scaling up section for enhancement paths.


### Training Data

- [ADFA IDS datasets](https://dataverse.harvard.edu/dataset.xhtml?persistentId=doi:10.7910/DVN/IFTZPF). Specifically, the [ADFA-LD dataset](https://dataverse.harvard.edu/file.xhtml?fileId=8083464&version=1.0) for Linux / Ubuntu host-based detection:



### Why BPF and not a custom kernel module?

BPF provides a virtual-machine-like container within the kernel, facilitating interfaces for dynamic instrumentation. The container adds layers of security and bug prevention, even requiring verification and compilation before executing in the BPF vm. Kprobes make "dynamic" possible, with the ability to attach instrumentation to kernel interfaces in a live production system without other modifications.

LLVM can target BPF directly from c code, and is the realm of performance toolset developers. BCC and bpftrace providing higher levels of abstraction. 

### Resources

eBPF.io
https://ebpf.io/

Brendan Gregg, BPF Performance Tools
https://learning.oreilly.com/library/view/bpf-performance-tools/9780136588870/